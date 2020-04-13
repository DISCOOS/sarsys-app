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

  Stream<Position> _stream;
  StreamSubscription _configSubscription;
  StreamSubscription _locatorSubscription;

  int get events => _events.length;

  LocationEvent operator [](int index) => _events[index];

  factory LocationService(AppConfigBloc bloc) {
    if (_singleton == null) {
      _singleton = LocationService._internal(bloc);
    }
    return _singleton;
  }

  Position get current => _current;
  Stream<Position> get stream => _stream;
  PermissionStatus get status => _status;
  ValueNotifier<bool> get isReady => _isReady;

  Future<PermissionStatus> configure() async {
    _status = await PermissionHandler().checkPermissionStatus(
      PermissionGroup.locationWhenInUse,
    );
    if ([PermissionStatus.granted, PermissionStatus.restricted].contains(_status)) {
      final config = _appConfigBloc.config;
      var options = _toOptions(config);
      if (_isConfigChanged(options)) {
        _subscribe(options);
        _configSubscription?.cancel();
        _configSubscription = _appConfigBloc.state.listen(
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
    if (_stream != null) _unsubscribe();
    _options = options;
    _stream = _geolocator.getPositionStream(_options).asBroadcastStream();
    _locatorSubscription = _stream.listen((Position position) {
      _current = position;
      _events.insert(0, PositionEvent(position));
    });
    _locatorSubscription.onDone(_unsubscribe);
    _locatorSubscription.onError(_handleError);
    try {
      _current = await _geolocator.getLastKnownPosition(desiredAccuracy: _options.accuracy);
      if (_current == null) {
        _current = await _geolocator.getCurrentPosition(
          desiredAccuracy: _options.accuracy,
        );
      }
      _isReady.value = true;
      _events.insert(0, SubscribeEvent(options));
    } on Exception catch (e, stackTrace) {
      _events.insert(0, ErrorEvent(options, e, stackTrace));
      _unsubscribe();
      Catcher.reportCheckedError("Failed to get position with error: $e", StackTrace.current);
    }
  }

  void dispose() {
    _configSubscription?.cancel();
    _configSubscription = null;
    _unsubscribe();
  }

  void _unsubscribe() {
    _stream = null;
    _locatorSubscription?.cancel();
    _locatorSubscription = null;
    _isReady.value = false;
    _events.insert(0, UnsubscribeEvent(_options));
  }

  bool _isConfigChanged(LocationOptions options) {
    return _options?.accuracy != options.accuracy ||
        _options?.timeInterval != options.timeInterval ||
        _options?.distanceFilter != options.distanceFilter;
  }

  _handleError(dynamic error, StackTrace stackTrace) {
    _unsubscribe();
    _events.insert(0, ErrorEvent(_options, error, stackTrace));
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
  String toString() => 'Accuracy: ${config.locationAccuracy}\n'
      'Interval: ${config.locationFastestInterval}\n'
      'Displacement: ${config.locationSmallestDisplacement}\n'
      'Permission: ${config.locationWhenInUse}';
}

class PositionEvent extends LocationEvent {
  PositionEvent(this.position) : super(StackTrace.current);
  final Position position;

  @override
  String toString() {
    return 'Position: $position';
  }
}

class SubscribeEvent extends LocationEvent {
  SubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'Accuracy: ${options.accuracy}, '
      'TimeInterval: ${options.timeInterval}, '
      'DistanceFilter: ${options.distanceFilter}, '
      'ForceAndroidLocationManager: ${options.forceAndroidLocationManager}';
}

class UnsubscribeEvent extends LocationEvent {
  UnsubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'Accuracy: ${options.accuracy}, '
      'TimeInterval: ${options.timeInterval}, '
      'DistanceFilter: ${options.distanceFilter}, '
      'ForceAndroidLocationManager: ${options.forceAndroidLocationManager}';
}

class ErrorEvent extends LocationEvent {
  ErrorEvent(this.options, this.error, StackTrace stackTrace) : super(stackTrace);
  final Object error;
  final LocationOptions options;
  @override
  String toString() => 'Error: $error, stackTrace: $stackTrace'
      'Accuracy: ${options.accuracy}, '
      'TimeInterval: ${options.timeInterval}, '
      'DistanceFilter: ${options.distanceFilter}, '
      'ForceAndroidLocationManager: ${options.forceAndroidLocationManager}';
}
