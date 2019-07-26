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
  static createTrackingAsJson(String id, List<String> devices, Point center, TrackingStatus status) {
    final rnd = math.Random();
    final location = createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
    return json.decode('{'
        '"id": "$id",'
        '"status": "${enumName(status)}",'
        '"location": $location,'
        '"distance": 0,'
        '"devices": ["${devices.join(",")}"],'
        '"track": [$location]'
        '}');
  }

  static double nextDouble(rnd, double fraction) {
    return (-100 + rnd.nextInt(200)).toDouble() / 100 * fraction;
  }

  static String createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  static TrackingService build(final IncidentBloc bloc, final count) {
    final TrackingServiceMock mock = TrackingServiceMock();
    final Map<String, Tracking> tracks = {};
    when(mock.fetch(any)).thenAnswer((_) async {
      Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
      tracks
        ..clear()
        ..addEntries([
          for (var i = 1; i <= count; i++)
            Tracking.fromJson(
              TracksBuilder.createTrackingAsJson("t$i", List.from(["d$i"]), center, TrackingStatus.Created),
            ),
        ].map((tracking) => MapEntry(tracking.id, tracking)));
      return Future.value(tracks.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var unit = _.positionalArguments[0];
      if (tracks.containsKey(unit.tracking)) {
        var devices = _.positionalArguments[1];
        Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
        return Future.value(
          TracksBuilder.createTrackingAsJson(
            Uuid().v1(),
            devices,
            center,
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
        return Future.value(tracking);
      }
      return Future.error("404 Not found. Tracking ${tracking.id}");
    });
    return mock;
  }
}
