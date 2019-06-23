import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:mockito/mockito.dart';

class TracksBuilder {
  static createTrackingAsJson(String id, Point center, TrackingState state) {
    final rnd = math.Random();
    return json.decode('{'
        '"id": "$id",'
        '"state": "${enumName(state)}",'
        '"location": ${createPointAsJson(center.lat + _nextDouble(rnd, 0.03), center.lon + _nextDouble(rnd, 0.03))},'
        '"distance": 0,'
        '"devices": [],'
        '"track": []'
        '}');
  }

  static _nextDouble(rnd, double fraction) {
    return (-100 + rnd.nextInt(200)).toDouble() / 100 * fraction;
  }

  static createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  static TrackingService build(final IncidentBloc bloc, final count) {
    final TrackingServiceMock mock = TrackingServiceMock();
    when(mock.fetch()).thenAnswer((_) async {
      Point center = bloc.isUnset ? Point.now(59.5, 10.09) : bloc.current.ipp;
      return Future.value([
        for (var i = 1; i <= count; i++)
          Tracking.fromJson(TracksBuilder.createTrackingAsJson("t$i", center, TrackingState.Created)),
      ]);
    });
    return mock;
  }
}
