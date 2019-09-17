import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static LocationService _singleton;
  final _isReady = ValueNotifier(false);

  Position _current;
  Geolocator _geolocator;
  PermissionStatus _status = PermissionStatus.unknown;

  LocationOptions _options;
  AppConfigBloc _appConfigBloc;

  Stream<Position> _stream;
  StreamSubscription _configSubscription;
  StreamSubscription _locatorSubscription;

  factory LocationService(AppConfigBloc bloc) {
    if (_singleton == null) {
      _singleton = LocationService._internal(bloc);
    }
    return _singleton;
  }

  LocationService._internal(AppConfigBloc bloc) {
    _appConfigBloc = bloc;
    _geolocator = Geolocator();
  }

  Position get current => _current;
  Stream<Position> get stream => _stream;
  ValueNotifier<bool> get isReady => _isReady;
  PermissionStatus get status => _status;

  Future<PermissionStatus> configure() async {
    _status = await PermissionHandler().checkPermissionStatus(PermissionGroup.locationWhenInUse);
    if ([PermissionStatus.granted, PermissionStatus.restricted].contains(_status)) {
      final config = _appConfigBloc.config;
      var options = _toOptions(config);
      if (_isConfigChanged(options)) {
        _subscribe(options);
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
    });
    _current = await _geolocator.getLastKnownPosition(desiredAccuracy: _options.accuracy);
    if (_current == null) _current = await _geolocator.getCurrentPosition(desiredAccuracy: _options.accuracy);
    _isReady.value = true;
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
  }

  bool _isConfigChanged(LocationOptions options) {
    return _options?.accuracy != options.accuracy ||
        _options?.timeInterval != options.timeInterval ||
        _options?.distanceFilter != options.distanceFilter;
  }
}
