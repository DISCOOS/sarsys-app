import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

class LocationService {
  LocationService._internal(AppConfigBloc bloc) {
    _appConfigBloc = bloc;
    _geolocator = Geolocator();
    _events.insert(0, CreateEvent(bloc.config));
  }
  static List<LocationEvent> _events = [];

  static LocationService _singleton;
  final _isReady = ValueNotifier(false);

  Position _current;
  Geolocator _geolocator;
  PermissionStatus _status = PermissionStatus.unknown;

  AppConfigBloc _appConfigBloc;
  LocationOptions _options;

  Stream<Position> _internalStream;
  StreamSubscription _configSubscription;
  StreamSubscription _locatorSubscription;
  StreamController<Position> _positionController = StreamController.broadcast();
  StreamController<LocationEvent> _eventController = StreamController.broadcast();

  factory LocationService(AppConfigBloc bloc) {
    if (_singleton == null || _singleton.disposed) {
      _singleton = LocationService._internal(bloc);
    }
    return _singleton;
  }

  Position get current => _current;
  PermissionStatus get status => _status;
  ValueNotifier<bool> get isReady => _isReady;
  Stream<Position> get stream => _positionController.stream;
  Stream<LocationEvent> get onChanged => _eventController.stream;
  Iterable<LocationEvent> get events => List.unmodifiable(_events);

  LocationEvent operator [](int index) => _events[index];

  Future<Position> update() async {
    if (_isReady.value) {
      try {
        final last = _current;
        _current = await _geolocator.getLastKnownPosition(desiredAccuracy: _options.accuracy);
        if (_current == null) {
          _current = await _geolocator.getCurrentPosition(
            desiredAccuracy: _options.accuracy,
          );
        }
        if (last != _current) {
          _positionController.add(_current);
          _notify(PositionEvent(_current));
        }
      } on Exception catch (e, stackTrace) {
        _notify(ErrorEvent(_options, e, stackTrace));
        _unsubscribe();
        Catcher.reportCheckedError("Failed to get position with error: $e", StackTrace.current);
      }
    } else {
      await configure();
    }
    return _current;
  }

  void _notify(LocationEvent event) {
    _events.insert(0, event);
    _eventController.add(event);
  }

  Future<PermissionStatus> configure({bool force = false}) async {
    _status = await PermissionHandler().checkPermissionStatus(
      PermissionGroup.locationWhenInUse,
    );
    if ([PermissionStatus.granted].contains(_status)) {
      final config = _appConfigBloc.config;
      var options = _toOptions(config);
      if (force || _isConfigChanged(options)) {
        _subscribe(options);
        _configSubscription?.cancel();
        _configSubscription = _appConfigBloc.listen(
          (state) {
            if (state.data is AppConfig) {
              final options = _toOptions(state.data);
              if (_isConfigChanged(options)) {
                _subscribe(options);
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

  LocationOptions _toOptions(AppConfig config) {
    return LocationOptions(
      accuracy: config.toLocationAccuracy(),
      timeInterval: config.locationFastestInterval,
      distanceFilter: config.locationSmallestDisplacement,
    );
  }

  void _subscribe(LocationOptions options) async {
    if (_internalStream != null) _unsubscribe();
    _options = options;
    _internalStream = _geolocator.getPositionStream(_options);
    _locatorSubscription = _internalStream.listen((Position position) {
      _current = position;
      _positionController.add(position);
      _notify(PositionEvent(position));
    });
    _locatorSubscription.onDone(_unsubscribe);
    _locatorSubscription.onError(_handleError);
    _notify(SubscribeEvent(options));
    _isReady.value = true;
    await update();
  }

  bool get disposed => _disposed;
  bool _disposed = false;

  void dispose() {
    _eventController.close();
    _positionController.close();
    _configSubscription?.cancel();
    _eventController = null;
    _positionController = null;
    _configSubscription = null;
    _unsubscribe();
    _disposed = true;
  }

  void _unsubscribe() {
    _internalStream = null;
    _locatorSubscription?.cancel();
    _locatorSubscription = null;
    _isReady.value = false;
    _notify(UnsubscribeEvent(_options));
  }

  bool _isConfigChanged(LocationOptions options) {
    return _options?.accuracy != options.accuracy ||
        _options?.timeInterval != options.timeInterval ||
        _options?.distanceFilter != options.distanceFilter;
  }

  _handleError(dynamic error, StackTrace stackTrace) {
    _unsubscribe();
    _notify(ErrorEvent(_options, error, stackTrace));
    Catcher.reportCheckedError("Location stream failed with error: $error", stackTrace);
  }

  static toAccuracyName(LocationAccuracy value) {
    switch (value) {
      case LocationAccuracy.lowest:
        return "Lavest";
      case LocationAccuracy.low:
        return "Lav";
      case LocationAccuracy.medium:
        return "Medium";
      case LocationAccuracy.high:
        return "Høy";
      case LocationAccuracy.best:
        return "Best";
      case LocationAccuracy.bestForNavigation:
        return "Navigasjon";
    }
  }
}

abstract class LocationEvent {
  LocationEvent(this.stackTrace);
  final StackTrace stackTrace;
  final DateTime timestamp = DateTime.now();
}

class CreateEvent extends LocationEvent {
  CreateEvent(this.config) : super(StackTrace.current);
  final AppConfig config;

  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'AppConfig: {\n'
      '   accuracy: ${config.locationAccuracy}\n'
      '   interval: ${config.locationFastestInterval}\n'
      '   displacement: ${config.locationSmallestDisplacement}\n'
      '   permission: ${config.locationWhenInUse}\n'
      '}';
}

class PositionEvent extends LocationEvent {
  PositionEvent(this.position) : super(StackTrace.current);
  final Position position;

  @override
  String toString() {
    return 'When: ${timestamp.toIso8601String()}\n'
        'Position: {\n'
        '   lat: ${position.latitude}\n'
        '   lon: ${position.longitude}\n'
        '   alt: ${position.altitude}\n'
        '   acc: ${position.accuracy}\n'
        '   heading: ${position.heading}\n'
        '   speed: ${position.speed}\n'
        '   speedAcc: ${position.speedAccuracy}\n'
        '   time: ${position.timestamp.toIso8601String()}\n'
        '}';
  }
}

class SubscribeEvent extends LocationEvent {
  SubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}

class UnsubscribeEvent extends LocationEvent {
  UnsubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}

class ErrorEvent extends LocationEvent {
  ErrorEvent(this.options, this.error, StackTrace stackTrace) : super(stackTrace);
  final Object error;
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Error: {\n'
      '   message: $error\n'
      '   stackTrace: $stackTrace\n'
      '}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}
