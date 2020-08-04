import 'dart:async';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'package:SarSys/core/domain/models/Position.dart';

import 'location_service.dart';

class BackgroundGeolocationService implements LocationService {
  BackgroundGeolocationService({
    String duuid,
    AuthToken token,
    this.configBloc,
    bool share = true,
    this.history = 100,
  }) {
    assert(configBloc != null, "AppConfigBloc must be supplied");
    _duuid = duuid;
    _token = token;
    _share = share ?? false;
    _events.insert(0, CreateEvent(duuid, configBloc.config));
  }

  static List<Position> _positions = [];
  static List<LocationEvent> _events = [];

  final int history;

  @override
  String get duuid => _duuid;
  String _duuid;

  @override
  bool get canStore => _options.locationStoreLocally ?? Defaults.locationStoreLocally;

  @override
  bool get isStoring => isReady.value && canStore;

  @override
  bool get canShare =>
      _duuid != null && _token != null && _options.locationAllowSharing ?? Defaults.locationAllowSharing;

  bool get share => _share;
  bool _share = true;

  @override
  bool get isSharing => _share && canShare;

  @override
  Iterable<Position> get positions => _positions;

  @override
  Future<Iterable<Position>> backlog() async {
    final locations = await bg.BackgroundGeolocation.locations;
    return locations.map(_fromJson).toList();
  }

  Position _fromJson(json) => Position.fromJson(Map<String, dynamic>.from(json));

  @override
  Future clear() async {
    _events.clear();
    _positions.clear();
    await bg.BackgroundGeolocation.destroyLocations();
    _notify(ClearEvent(current));
  }

  @override
  final AppConfigBloc configBloc;

  AuthToken _token;
  LocationOptions _options;
  PermissionStatus _status = PermissionStatus.undetermined;

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
  AuthToken get token => _token;

  @override
  set token(AuthToken token) {
    if (_isReady.value) {
      bg.BackgroundGeolocation.setConfig(
        _toConfig(token: token),
      );
    }
  }

  @override
  Future<PermissionStatus> configure({
    bool share,
    String duuid,
    AuthToken token,
    bool debug = false,
    bool force = false,
  }) async {
    _status = await Permission.locationWhenInUse.status;

    if ([PermissionStatus.granted].contains(_status)) {
      _options ??= _toOptions(
        configBloc.config,
        debug: debug,
      );
      if (_configSubscription == null) {
        bg.BackgroundGeolocation.ready(_toConfig(
          duuid: duuid,
          token: token,
          share: share,
          debug: debug,
        )).then((bg.State state) async {
          if (!state.enabled) {
            await bg.BackgroundGeolocation.start();
          }
          // Prepare
          _positions = await backlog();
          _notify(ConfigureEvent(
            duuid,
            configBloc.config,
            _options,
          ));
          _subscribe();
          await bg.BackgroundGeolocation.getCurrentPosition();
        });
        _configSubscription = configBloc.listen(
          (state) async {
            if (state.data is AppConfig) {
              if (_isConfigChanged(state.data)) {
                _options = _toOptions(
                  state.data,
                  debug: _options.debug ?? kDebugMode,
                );
                await bg.BackgroundGeolocation.setConfig(
                  _toConfig(),
                );
                _notify(ConfigureEvent(
                  duuid,
                  configBloc.config,
                  _options,
                ));
              }
            }
          },
        );
      }

      if (force ||
          _isConfigChanged(
            configBloc.config,
            duuid: duuid,
            token: token,
            debug: debug,
            share: share,
          )) {
        await bg.BackgroundGeolocation.setConfig(_toConfig(
          duuid: duuid,
          token: token,
          share: share,
          debug: debug,
        ));
        _notify(ConfigureEvent(
          duuid,
          configBloc.config,
          _options,
        ));
      }
    } else {
      await dispose();
    }
    return _status;
  }

  LocationOptions _toOptions(AppConfig config, {@required bool debug}) => LocationOptions(
        debug: debug,
        accuracy: config.toLocationAccuracy(),
        locationAlways: config.locationAlways ?? false,
        locationWhenInUse: config.locationWhenInUse ?? false,
        activityRecognition: config.activityRecognition ?? false,
        timeInterval: config.locationFastestInterval ?? Defaults.locationFastestInterval,
        locationStoreLocally: config.locationStoreLocally ?? Defaults.locationStoreLocally,
        locationAllowSharing: config.locationAllowSharing ?? Defaults.locationAllowSharing,
        distanceFilter: config.locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement,
      );

  bg.Config _toConfig({
    bool share,
    bool debug,
    String duuid,
    AuthToken token,
  }) {
    _duuid = duuid ?? _duuid;
    _token = token ?? _token;
    _share = share ?? _share;
    final url = isSharing ? '${Defaults.baseRestUrl}/devices/$_duuid/positions' : null;
    return bg.Config(
      batchSync: true,
      maxBatchSize: 10,
      autoSync: isSharing,
      autoSyncThreshold: 5,
      startOnBoot: isSharing,
      stopOnTerminate: isSharing,
      url: url,
      method: 'POST',
      logMaxDays: 3,
      logLevel: _logLevel,
      maxDaysToPersist: 3,
      maxRecordsToPersist: 1000,
      persistMode: _persistMode,
      httpRootProperty: '.',
      authorization: _toAuthorization(),
      locationTemplate: _toLocationTemplate(),
      showsBackgroundLocationIndicator: true,
      // We handle permissions our self
      disableLocationAuthorizationAlert: true,
      debug: debug ?? _options.debug ?? kDebugMode,
      locationUpdateInterval: _options.timeInterval,
      desiredAccuracy: _toAccuracy(_options.accuracy),
      distanceFilter: _options.distanceFilter.toDouble(),
      fastestLocationUpdateInterval: _options.timeInterval,
      disableMotionActivityUpdates: !_options.activityRecognition,
      notification: Notification(
        title: "SARSys",
        text: "Sporing er ${isSharing ? 'aktiv' : 'inaktiv'}",
      ),
    );
  }

  Authorization _toAuthorization() {
    return Authorization(
        accessToken: _token.accessToken,
        refreshToken: _token.refreshToken,
        refreshUrl: UserIdentityService.REFRESH_URL,
        refreshPayload: {
          'client_id': _token.clientId,
          'grant_type': 'refresh_token',
          'refresh_token': '{refreshToken}',
        });
  }

  int get _logLevel => kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_INFO;
  int get _persistMode => canStore ? bg.Config.PERSIST_MODE_LOCATION : bg.Config.PERSIST_MODE_NONE;

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
        return bg.Config.DESIRED_ACCURACY_HIGH;
      case LocationAccuracy.navigation:
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
        Catcher.reportCheckedError(
          "Failed to get position with error: $e",
          StackTrace.current,
        );
      }
    } else {
      await configure();
    }
    return _current;
  }

  @override
  Future<int> push() async {
    final pushed = [];
    if (_isReady.value) {
      try {
        pushed.addAll(await bg.BackgroundGeolocation.sync());
        _notify(PushEvent(pushed.map(_fromJson)));
      } on Exception catch (e, stackTrace) {
        if (_shouldReport(e)) {
          _notify(ErrorEvent(_options, e, stackTrace));

          Catcher.reportCheckedError(
            "Failed to push backlog error: $e",
            StackTrace.current,
          );
        }
      }
    }
    return pushed.length;
  }

  bool _shouldReport(Exception e) {
    return !(e is PlatformException &&
        !const [
          'timeout',
          'HTTPService is busy',
        ].contains('${e.message}'));
  }

  @override
  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  Future dispose() async {
    if (!_disposed) {
      _isReady.value = false;
      _notify(UnsubscribeEvent(_options));
      await _eventController.close();
      await _positionController.close();
      await _configSubscription?.cancel();
      _eventController = null;
      _positionController = null;
      _configSubscription = null;
      _disposed = true;
    }
    return Future.value();
  }

  bool _isDeviceChanged(String duuid) => duuid != null && duuid != _duuid;
  bool _isTokenChanged(AuthToken token) => token != null && token != _token;
  bool _isSharingStateChanged(bool share) => share != null && share != _share;

  bool _isConfigChanged(
    AppConfig config, {
    bool share,
    bool debug,
    String duuid,
    AuthToken token,
  }) {
    return _options?.debug != (debug ?? kDebugMode) ||
        _options?.accuracy != config.toLocationAccuracy() ||
        _options?.locationAlways != (config.locationAlways ?? false) ||
        _options?.locationWhenInUse != (config.locationWhenInUse ?? false) ||
        _options?.activityRecognition != (config.activityRecognition ?? false) ||
        _options?.timeInterval != (config.locationFastestInterval ?? Defaults.locationFastestInterval) ||
        _options?.locationStoreLocally != (config.locationStoreLocally ?? Defaults.locationStoreLocally) ||
        _options?.locationAllowSharing != (config.locationAllowSharing ?? Defaults.locationAllowSharing) ||
        _options?.distanceFilter != (config.locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement) ||
        _isTokenChanged(token) ||
        _isDeviceChanged(duuid) ||
        _isSharingStateChanged(share);
  }

  void _subscribe() async {
    if (!_isReady.value) {
      // Process for location changes
      bg.BackgroundGeolocation.onLocation(
        _onLocation,
        _onError,
      );

      // Process http service events
      bg.BackgroundGeolocation.onHttp(_onHttp);
      bg.BackgroundGeolocation.onMotionChange(_onMove);
      bg.BackgroundGeolocation.onAuthorization(_onAuthorization);
      _notify(SubscribeEvent(_options));
      _isReady.value = true;
    }
    await update();
  }

  void _onLocation(bg.Location location) {
    _current = _toPosition(location);
    _positionController.add(_current);
    _notify(PositionEvent(_current));
  }

  void _onMove(bg.Location location) {
    _notify(
      MoveEvent(_toPosition(location), location.isMoving),
    );
  }

  void _onHttp(event) {
    _notify(
      HttpServiceEvent(
        _options,
        event.status,
        event.responseText,
      ),
    );
  }

  void _onAuthorization(AuthorizationEvent event) {
    if (event.success) {
      _token = AuthToken(
        idToken: _token.idToken,
        clientId: _token.clientId,
        accessToken: event.response['access_token'],
        refreshToken: event.response['refresh_token'],
        accessTokenExpiration: DateTime.now()
          ..add(
            Duration(seconds: event.response['expires_in'] ?? 300),
          ),
      );
      _notify(
        HttpServiceEvent(_options, 200, '{$event.response}'),
      );
    } else {
      _notify(
        HttpServiceEvent(_options, 401, event.error),
      );
    }
  }

  void _notify(LocationEvent event) {
    if ((_events?.length ?? 0) > history) {
      _events.removeLast();
    }
    _events.insert(0, event);
    if (event is PositionEvent) {
      _positions.add(event.position);
    }
    _eventController.add(event);
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
