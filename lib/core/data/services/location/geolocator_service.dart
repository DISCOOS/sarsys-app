import 'dart:async';

import 'package:SarSys/core/domain/models/Position.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:permission_handler/permission_handler.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

import 'location_service.dart';

class GeolocatorService implements LocationService {
  GeolocatorService(AppConfigBloc bloc) {
    assert(bloc != null, "AppConfigBloc must be supplied");
    _bloc = bloc;
    _geolocator = gl.Geolocator();
    _events.insert(0, CreateEvent(bloc.config));
  }

  static List<LocationEvent> _events = [];

  final _isReady = ValueNotifier(false);

  Position _current;
  gl.Geolocator _geolocator;
  PermissionStatus _status = PermissionStatus.unknown;

  AppConfigBloc _bloc;
  LocationOptions _options;

  Stream<Position> _internalStream;
  StreamSubscription _configSubscription;
  StreamSubscription _locatorSubscription;
  StreamController<Position> _positionController = StreamController.broadcast();
  StreamController<LocationEvent> _eventController = StreamController.broadcast();

  @override
  Position get current => _current;

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
      final config = _bloc.config;
      var options = _toOptions(config);
      if (force || _isConfigChanged(options)) {
        _subscribe(options);
        _configSubscription?.cancel();
        _configSubscription = _bloc.listen(
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

  @override
  Future<Position> update() async {
    if (_isReady.value) {
      try {
        final last = _current;
        _current = _toPosition(
          await _geolocator.getLastKnownPosition(
            desiredAccuracy: _toAccuracy(_options.accuracy),
          ),
        );
        if (_current == null) {
          _current = _toPosition(
            await _geolocator.getCurrentPosition(
              desiredAccuracy: _toAccuracy(_options.accuracy),
            ),
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

  LocationOptions _toOptions(AppConfig config) {
    return LocationOptions(
      accuracy: config.toLocationAccuracy(),
      timeInterval: config.locationFastestInterval,
      distanceFilter: config.locationSmallestDisplacement,
    );
  }

  static gl.LocationAccuracy _toAccuracy(LocationAccuracy value) {
    switch (value) {
      case LocationAccuracy.lowest:
        return gl.LocationAccuracy.lowest;
      case LocationAccuracy.low:
        return gl.LocationAccuracy.low;
      case LocationAccuracy.medium:
        return gl.LocationAccuracy.medium;
      case LocationAccuracy.high:
        return gl.LocationAccuracy.high;
      case LocationAccuracy.best:
        return gl.LocationAccuracy.best;
      case LocationAccuracy.bestForNavigation:
        return gl.LocationAccuracy.bestForNavigation;
      default:
        return gl.LocationAccuracy.best;
    }
  }

  void _subscribe(LocationOptions options) async {
    if (_internalStream != null) _unsubscribe();
    _options = options;
    _internalStream = _geolocator
        .getPositionStream(gl.LocationOptions(
          accuracy: _toAccuracy(options.accuracy),
          distanceFilter: options.distanceFilter,
          timeInterval: options.timeInterval,
          forceAndroidLocationManager: options.forceAndroidLocationManager,
        ))
        .map(_toPosition);
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

  @override
  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  Future dispose() async {
    await _eventController.close();
    await _positionController.close();
    await _configSubscription?.cancel();
    _eventController = null;
    _positionController = null;
    _configSubscription = null;
    _unsubscribe();
    _disposed = true;
    return Future.value();
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
    Catcher.reportCheckedError(
      "Location stream failed with error: $error",
      stackTrace,
    );
  }

  Position _toPosition(gl.Position position) => Position.timestamp(
        lat: position.latitude,
        lon: position.longitude,
        alt: position.altitude,
        acc: position.accuracy,
        speed: position.speed,
        bearing: position.heading,
        timestamp: position.timestamp,
        source: PositionSource.device,
      );
}
