import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';

class LocationService {
  static final _singleton = LocationService._internal();
  final _isReady = ValueNotifier(false);

  String _serverUrl = "https://sporing.rodekors.no/locationtest"; // For testing simple tracking with POST messages

  Position _current;
  Geolocator _geolocator;
  GeolocationStatus _status;

  Stream<Position> _stream;
  StreamSubscription<Position> _subscription;

  factory LocationService() {
    return _singleton;
  }

  LocationService._internal() {
    init();
  }

  Position get current => _current;
  Stream<Position> get stream => _stream;
  ValueNotifier<bool> get isReady => _isReady;
  GeolocationStatus get status => _status;

//
//  bool _locationEnabled;
//  bool _sendingLocation;

//  // Starts background location and stores to SQLite
//  startTrackSave() {}
//
//  stopTrackSave() {}
//
//  startTrackSend() {}
//
//  stopTrackSend() {}

  Future<GeolocationStatus> init() async {
    _status = await Geolocator().checkGeolocationPermissionStatus();
    switch (_status) {
      case GeolocationStatus.granted:
      case GeolocationStatus.restricted:
        {
          _geolocator = Geolocator();
          var options = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

          _stream = _geolocator.getPositionStream(options).asBroadcastStream();
          _subscription = _stream.listen((Position position) {
            print(position == null
                ? 'Position unknown'
                : "Current position: ${position.latitude}, ${position.longitude}");
            _current = position;
          });
          _current = await _geolocator.getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);
          _isReady.value = true;
          break;
        }
      case GeolocationStatus.disabled:
      case GeolocationStatus.denied:
      case GeolocationStatus.unknown:
        {
          dispose();
        }
    }
    return _status;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isReady.value = false;
  }
}

class LocationReport {
  double lat;
  double lon;
  int timestamp;
  int accuracy;
}
