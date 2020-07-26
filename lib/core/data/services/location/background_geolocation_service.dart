import 'dart:async';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';

import 'location_service.dart';

class BackgroundGeolocationService implements LocationService {
  BackgroundGeolocationService(AppConfigBloc bloc) {
    assert(bloc != null, "AppConfigBloc must be supplied");
    _bloc = bloc;
    _events.insert(0, CreateEvent(bloc.config));
  }

  static List<LocationEvent> _events = [];

  final _isReady = ValueNotifier(false);

  PermissionStatus _status = PermissionStatus.unknown;

  AppConfigBloc _bloc;
  LocationOptions _options;

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

  @override
  Stream<Position> get stream => _positionController.stream;

  @override
  Stream<LocationEvent> get onChanged => _eventController.stream;

  @override
  Iterable<LocationEvent> get events => List.unmodifiable(_events);

  @override
  LocationEvent operator [](int index) => _events[index];

  @override
  Future<PermissionStatus> configure({bool force = false}) async {
    _status = await PermissionHandler().checkPermissionStatus(
      PermissionGroup.locationWhenInUse,
    );
    if ([PermissionStatus.granted].contains(_status)) {
      _options ??= _toOptions(_bloc.config);
      bg.BackgroundGeolocation.ready(_toConfig()).then((bg.State state) {
        if (!state.enabled) {
          bg.BackgroundGeolocation.start();
        }
        _subscribe();
      });

      if (force || _isConfigChanged(_bloc.config)) {
        bg.BackgroundGeolocation.setConfig(_toConfig());
        _configSubscription ??= _bloc.listen(
          (state) {
            if (state.data is AppConfig) {
              if (_isConfigChanged(state.data)) {
                _options = _toOptions(state.data);
                bg.BackgroundGeolocation.setConfig(_toConfig());
              }
            }
          },
        );
      }
    } else {
      dispose();
    }
    return _status;
  }

  LocationOptions _toOptions(AppConfig config) => LocationOptions(
        accuracy: config.toLocationAccuracy(),
        timeInterval: config.locationFastestInterval,
        distanceFilter: (config.locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement),
      );

  bg.Config _toConfig() => bg.Config(
        desiredAccuracy: _toAccuracy(_options.accuracy),
        distanceFilter: _options.distanceFilter.toDouble(),
        locationUpdateInterval: _options.timeInterval,
        stopOnTerminate: false,
        startOnBoot: true,
        debug: kDebugMode,
        logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_INFO,
      );

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
        _onLocation(
          await bg.BackgroundGeolocation.getCurrentPosition(),
        );
        _positionController.add(_current);
        _notify(PositionEvent(_current));
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

  bool _isConfigChanged(AppConfig config) {
    return _options?.accuracy != config.toLocationAccuracy() ||
        _options?.timeInterval != config.locationFastestInterval ||
        _options?.distanceFilter != config.locationSmallestDisplacement;
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
    _current = Position.timestamp(
      lat: location.coords.latitude,
      lon: location.coords.longitude,
      alt: location.coords.altitude,
      acc: location.coords.accuracy,
      speed: location.coords.speed,
      source: PositionSource.device,
      bearing: location.coords.heading,
      timestamp: DateTime.tryParse(location.timestamp) ?? DateTime.now(),
    );
    _positionController.add(_current);
    _notify(PositionEvent(_current));
  }

  void _onError(bg.LocationError error) {
    final stackTrace = StackTrace.current;
    _notify(ErrorEvent(_options, error, stackTrace));
    Catcher.reportCheckedError(
      "Location stream failed with error: $error",
      stackTrace,
    );
  }
}
