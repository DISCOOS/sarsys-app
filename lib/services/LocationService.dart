import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';

class LocationService {
  bool locationEnabled;
  bool sendingLocation;

  String serverUrl = "https://sporing.rodekors.no/locationtest";    // For testing simple tracking with POST messages


  // Starts background location and stores to SQLite
  startTrackSave() {

  }

  stopTrackSave() {

  }

  startTrackSend() {

  }

  stopTrackSend() {

  }

  getLocation() async {
    return await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  }

  // TODO: private when done testing
  startLocationStream() {
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

    StreamSubscription<Position> positionStream = geolocator.getPositionStream(locationOptions).listen(
            (Position _position) {
          print(_position == null ? 'Unknown' : _position.latitude.toString() + ', ' + _position.longitude.toString());
        });
  }

}

class LocationReport {
  double lat;
  double lon;
  int timestamp;
  int accuracy;

}