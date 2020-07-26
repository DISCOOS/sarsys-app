import 'dart:async';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'package:SarSys/core/domain/models/Position.dart';

import 'location_service.dart';

class BackgroundGeolocationService implements LocationService {
  BackgroundGeolocationService({
    String duuid,
    String token,
    this.configBloc,
    bool track = true,
    bool share = false,
  }) {
    assert(configBloc != null, "AppConfigBloc must be supplied");
    _duuid = duuid;
    _token = token;
    _track = track ?? true;
    _share = share ?? false;
    _events.insert(0, CreateEvent(duuid, configBloc.config));
  }

  static List<LocationEvent> _events = [];

  @override
  String get duuid => _duuid;
  String _duuid;

  @override
  bool get isTracking => _track;
  bool _track = true;

  @override
  bool get isSharing => _share && _duuid != null && _token != null;
  bool _share = false;

  @override
  Iterable<Position> get positions => events.whereType<PositionEvent>().map((e) => e.position);

  @override
  Future<Iterable<Position>> history() async {
    final locations = await bg.BackgroundGeolocation.locations;
    return locations.map(_toPosition);
  }

  @override
  Future clear() async {
    _events.clear();
    return await bg.BackgroundGeolocation.destroyLocations();
  }

  @override
  final AppConfigBloc configBloc;

  String _token;
  LocationOptions _options;
  PermissionStatus _status = PermissionStatus.unknown;

  StreamSubscription _configSubscription;
  StreamController<Position> _positionController = StreamController.broadcast();
  StreamController<LocationEvent> _eventController = StreamController.broadcast();

  @override
  Position get current => _current;
  Position _current;

  @override
  PermissionStatus get status => _status;

  @override
  ValueNotifier<bool> get isReady => _isReady;
  final _isReady = ValueNotifier(false);

  @override
  Stream<Position> get stream => _positionController.stream;

  @override
  Stream<LocationEvent> get onChanged => _eventController.stream;

  @override
  Iterable<LocationEvent> get events => List.unmodifiable(_events);

  @override
  LocationEvent operator [](int index) => _events[index];

  @override
  String get token => _token;

  @override
  set token(String token) {
    if (_isReady.value) {
      bg.BackgroundGeolocation.setConfig(_toConfig(token: token));
    }
  }

  @override
  Future<PermissionStatus> configure({
    String duuid,
    String token,
    bool track,
    bool share,
    bool force = false,
  }) async {
    _status = await PermissionHandler().checkPermissionStatus(
      PermissionGroup.locationWhenInUse,
    );

    if ([PermissionStatus.granted].contains(_status)) {
      _options ??= _toOptions(configBloc.config);
      if (_configSubscription == null) {
        bg.BackgroundGeolocation.ready(_toConfig(
          duuid: duuid,
          token: token,
          track: track,
          share: share,
        )).then((bg.State state) async {
          if (!state.enabled) {
            await bg.BackgroundGeolocation.start();
          }
          await bg.BackgroundGeolocation.destroyLocations();
          _subscribe();
        });
        _configSubscription = configBloc.listen(
          (state) {
            if (state.data is AppConfig) {
              if (_isConfigChanged(state.data)) {
                _options = _toOptions(state.data);
                bg.BackgroundGeolocation.setConfig(_toConfig());
              }
            }
          },
        );
        bg.BackgroundGeolocation.onHttp((bg.HttpEvent response) {
          print('[http] success? ${response.success}, status? ${response.status}');
        });
      }

      if (force ||
          _isConfigChanged(
            configBloc.config,
            duuid: duuid,
            token: token,
            track: track,
            share: share,
          )) {
        bg.BackgroundGeolocation.setConfig(_toConfig(
          duuid: duuid,
          token: token,
          track: track,
          share: share,
        ));
      }
      await update();
    } else {
      await dispose();
    }
    return _status;
  }

  LocationOptions _toOptions(AppConfig config) => LocationOptions(
        accuracy: config.toLocationAccuracy(),
        timeInterval: config.locationFastestInterval,
        distanceFilter: (config.locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement),
      );

  bg.Config _toConfig({
    String duuid,
    String token,
    bool track,
    bool share,
  }) {
    _duuid = duuid ?? _duuid;
    _token = token ?? _token;
    _track = track ?? _track;
    _share = share ?? _share;
    final push = isSharing;
    final url = push ? '${Defaults.baseRestUrl}/devices/$duuid/positions' : null;
    return bg.Config(
      debug: kDebugMode,
      startOnBoot: true,
      stopOnTerminate: false,
      autoSync: push,
      batchSync: push,
      maxBatchSize: 10,
      autoSyncThreshold: 5,
      httpRootProperty: '.',
      httpTimeout: 5000,
      url: url,
      method: 'POST',
      headers: {
        if (push) "Authorization": "Bearer $_token",
      },
      logLevel: _logLevel,
      persistMode: _persistMode,
      locationTemplate: _toLocationTemplate(),
      locationUpdateInterval: _options.timeInterval,
      desiredAccuracy: _toAccuracy(_options.accuracy),
      distanceFilter: _options.distanceFilter.toDouble(),
    );
  }

  int get _logLevel => kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_INFO;
  int get _persistMode => _track ? bg.Config.PERSIST_MODE_LOCATION : bg.Config.PERSIST_MODE_NONE;

  int _toAccuracy(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return bg.Config.DESIRED_ACCURACY_LOWEST;
      case LocationAccuracy.low:
        return bg.Config.DESIRED_ACCURACY_LOW;
      case LocationAccuracy.medium:
        return bg.Config.DESIRED_ACCURACY_MEDIUM;
      case LocationAccuracy.high:
        return bg.Config.DESIRED_ACCURACY_HIGH;
      case LocationAccuracy.best:
      case LocationAccuracy.bestForNavigation:
        return bg.Config.DESIRED_ACCURACY_NAVIGATION;
      default:
        return bg.Config.DESIRED_ACCURACY_HIGH;
    }
  }

  @override
  Future<Position> update() async {
    if (_isReady.value) {
      try {
        await bg.BackgroundGeolocation.getCurrentPosition();
      } on Exception catch (e, stackTrace) {
        _notify(ErrorEvent(_options, e, stackTrace));
        Catcher.reportCheckedError("Failed to get position with error: $e", StackTrace.current);
      }
    } else {
      await configure();
    }
    return _current;
  }

  @override
  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  Future dispose() async {
    _isReady.value = false;
    _notify(UnsubscribeEvent(_options));
    await _eventController.close();
    await _positionController.close();
    await _configSubscription?.cancel();
    _eventController = null;
    _positionController = null;
    _configSubscription = null;
    _disposed = true;
    return Future.value();
  }

  bool _isTokenChanged(String token) => token != null && token != _token;
  bool _isDeviceChanged(String duuid) => duuid != null && duuid != _duuid;
  bool _isSharingStateChanged(bool share) => share != null && share != _share;
  bool _isTrackingStateChanged(bool track) => track != null && track != _track;

  bool _isConfigChanged(
    AppConfig config, {
    String duuid,
    String token,
    bool track,
    bool share,
  }) {
    return _options?.accuracy != config.toLocationAccuracy() ||
        _options?.timeInterval != config.locationFastestInterval ||
        _options?.distanceFilter != config.locationSmallestDisplacement ||
        _isDeviceChanged(duuid) ||
        _isTokenChanged(token) ||
        _isSharingStateChanged(track) ||
        _isTrackingStateChanged(share);
  }

  void _subscribe() async {
    if (!_isReady.value) {
      bg.BackgroundGeolocation.onLocation(
        _onLocation,
        _onError,
      );
      bg.BackgroundGeolocation.onMotionChange(
        _onLocation,
      );
      _notify(SubscribeEvent(_options));
      _isReady.value = true;
    }
    await update();
  }

  void _notify(LocationEvent event) {
    _events.insert(0, event);
    _eventController.add(event);
  }

  void _onLocation(bg.Location location) {
    _current = _toPosition(location);
    _positionController.add(_current);
    _notify(PositionEvent(_current));
  }

  Position _toPosition(bg.Location location) => Position.timestamp(
        lat: location.coords.latitude,
        lon: location.coords.longitude,
        alt: location.coords.altitude,
        acc: location.coords.accuracy,
        speed: location.coords.speed,
        source: PositionSource.device,
        bearing: location.coords.heading,
        timestamp: DateTime.tryParse(location.timestamp) ?? DateTime.now(),
      );

  void _onError(bg.LocationError error) {
    final stackTrace = StackTrace.current;
    _notify(ErrorEvent(_options, error, stackTrace));
    Catcher.reportCheckedError(
      "Location stream failed with error: $error",
      stackTrace,
    );
  }

  String _toLocationTemplate() {
    return '{'
        '"type": "Feature",'
        '"geometry": {"type": "Point", "coordinates": [<%= longitude %>, <%= latitude %>, <%= altitude %>]},'
        '"properties": {'
        '"source": "device",'
        '"timestamp": "<%= timestamp %>",'
        '"accuracy": <%= accuracy %>,'
        '"bearing": <%= heading %>,'
        '"speed": <%= speed %>'
        '}}';
  }
}
