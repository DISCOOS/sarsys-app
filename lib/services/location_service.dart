import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  static LocationService _singleton;
  final _isReady = ValueNotifier(false);

  Position _current;
  Geolocator _geolocator;
  GeolocationStatus _status = GeolocationStatus.unknown;

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
  GeolocationStatus get status => _status;

  Future<GeolocationStatus> configure() async {
    _status = await _geolocator.checkGeolocationPermissionStatus();
    switch (_status) {
      case GeolocationStatus.granted:
      case GeolocationStatus.restricted:
        {
          final config = _appConfigBloc.config;

          var options = _toOptions(config);

          if (_isConfigChanged(options)) {
            if (_stream != null) dispose();
            _configure(options);
            _configSubscription = _appConfigBloc.state.listen(
              (state) {
                print(state);
                if (state.data is AppConfig) {
                  final options = _toOptions(state.data);
                  if (_isConfigChanged(options)) {
                    _configure(options);
                  }
                }
              },
            );
          }
          break;
        }
      case GeolocationStatus.disabled:
      case GeolocationStatus.denied:
      case GeolocationStatus.unknown:
        {
          dispose();
          break;
        }
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

  void _configure(LocationOptions options) async {
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
    _locatorSubscription?.cancel();
    _stream = null;
    _configSubscription = null;
    _locatorSubscription = null;
    _isReady.value = false;
  }

  bool _isConfigChanged(LocationOptions options) {
    return _options?.accuracy != options.accuracy ||
        _options?.timeInterval != options.timeInterval ||
        _options?.distanceFilter != options.distanceFilter;
  }
}

class LocationReport {
  double lat;
  double lon;
  int timestamp;
  int accuracy;
}
