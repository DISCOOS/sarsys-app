import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

class TracksBuilder {
  static createTrackingAsJson(String id, List<String> devices, String location, TrackingStatus status) {
    return json.decode('{'
        '"id": "$id",'
        '"status": "${enumName(status)}",'
        '"location": $location,'
        '"distance": 0,'
        '"devices": ["${devices.join(",")}"],'
        '"track": [$location]'
        '}');
  }

  static String createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }

  static String createRandomPointAsJson(rnd, Point center) {
    return TracksBuilder.createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
  }

  static double nextDouble(rnd, double fraction, {negative: true}) {
    return (negative ? (-100 + rnd.nextInt(200)).toDouble() : rnd.nextInt(100)) / 100 * fraction;
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  static TrackingService build(final IncidentBloc bloc, final count) {
    final TrackingServiceMock mock = TrackingServiceMock();
    final rnd = math.Random();
    final Map<String, Tracking> tracks = {};
    final Map<String, _TrackSimulation> simulations = {};
    final simulator = Timer.periodic(Duration(seconds: 2), (timer) {
      simulations.forEach((id, simulation) {
        if (tracks.containsKey(id)) {
          var tracking = tracks[id];
          if (TrackingStatus.Tracking == tracking.status) {
            var location = simulation.progress();
            tracking = Tracking(
              id: tracking.id,
              location: location,
              status: tracking.status,
              devices: tracking.devices,
              distance: tracking.distance,
              track: tracking.track,
            );
            tracks.update(
              id,
              (_) => tracking,
              ifAbsent: () => tracking,
            );
          }
        }
      });
    });
    when(mock.fetch(any)).thenAnswer((_) async {
      if (tracks.isEmpty) {
        final Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
        tracks.addEntries([
          for (var i = 1; i <= count; i++)
            Tracking.fromJson(
              TracksBuilder.createTrackingAsJson(
                "t$i",
                List.from(["d$i"]),
                TracksBuilder.createRandomPointAsJson(rnd, center),
                TrackingStatus.Created,
              ),
            ),
        ].map((tracking) => MapEntry(tracking.id, tracking)));
      }
      return Future.value(tracks.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var unit = _.positionalArguments[0];
      if (tracks.containsKey(unit.tracking)) {
        var devices = _.positionalArguments[1];
        final Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
        return Future.value(
          TracksBuilder.createTrackingAsJson(
            Uuid().v1(),
            devices,
            TracksBuilder.createRandomPointAsJson(math.Random(), center),
            TrackingStatus.Created,
          ),
        );
      }
      return Future.error("409 Conflict. Tracking already exists for unit ${unit.id}");
    });
    when(mock.update(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      if (tracks.containsKey(tracking.id)) {
        tracks.update(
          tracking.id,
          (_) => tracking,
          ifAbsent: () => tracking,
        );
        _simulate(rnd, simulations, tracking);
        return Future.value(tracking);
      }
      return Future.error("404 Not found. Tracking ${tracking.id}");
    });
    return mock;
  }

  static void _simulate(rnd, Map<String, _TrackSimulation> simulations, Tracking tracking) {
    if (TrackingStatus.Tracking == tracking.status) {
      final simulation = _TrackSimulation(
        rnd: rnd,
        fraction: 0.02,
        id: tracking.id,
        location: tracking.location,
        steps: 16,
      );
      simulations.update(tracking.id, (_) => simulation, ifAbsent: () => simulation);
    } else {
      simulations.remove(tracking.id);
    }
  }
}

class _TrackSimulation {
  final String id;
  final int steps;
  final double fraction;
  final math.Random rnd;

  int current;
  Point location;

  _TrackSimulation({this.rnd, this.fraction, this.id, this.location, this.steps}) : current = 0;

  Point progress() {
    var leg = ((current / 4.0) % 4 + 1).toInt();
    switch (leg) {
      case 1:
        location = Point.now(
          location.lat,
          location.lon + TracksBuilder.nextDouble(rnd, fraction, negative: false),
        );
        break;
      case 2:
        location = Point.now(
          location.lat - TracksBuilder.nextDouble(rnd, fraction, negative: false),
          location.lon,
        );
        break;
      case 3:
        location = Point.now(
          location.lat,
          location.lon - TracksBuilder.nextDouble(rnd, fraction, negative: false),
        );
        break;
      case 4:
        location = Point.now(
          location.lat + TracksBuilder.nextDouble(rnd, fraction, negative: false),
          location.lon,
        );
        break;
    }
    current = (current + 1) % steps;
    return location;
  }
}
