import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:mockito/mockito.dart';

class TracksBuilder {
  static createTrackingAsJson(String id, int index, Point center, TrackingState state) {
    final rnd = math.Random();
    final location = createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
    return json.decode('{'
        '"id": "$id",'
        '"state": "${enumName(state)}",'
        '"location": $location,'
        '"distance": 0,'
        '"devices": ["d$index"],'
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
    when(mock.fetch(any)).thenAnswer((_) async {
      Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
      return Future.value([
        for (var i = 1; i <= count; i++)
          Tracking.fromJson(TracksBuilder.createTrackingAsJson("t$i", i, center, TrackingState.Created)),
      ]);
    });
    return mock;
  }
}
