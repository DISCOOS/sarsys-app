import 'dart:convert';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';

class IncidentBuilder {
  static createIncident(int since) {
    return json.decode(createIncidentAsJson(since));
  }

  static createIncidentAsJson(int since) {
    return '{'
        '"id": "${randomAlphaNumeric(16)}",'
        '"name": "Savnet person",'
        '"type": "Lost",'
        '"status": "Handling",'
        '"reference": "2019-RKH-245$since",'
        '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
        '"justification": "Mann, 32 år, økt selvmordsfare.",'
        '"ipp": ${createEmptyPointAsJson()},'
        '"talkgroups": ['
        '{"name": "RK-RIKS-1", "type": "Tetra"}'
        '],'
        '"passcodes": ${createPasscodesAsJson()}'
        '}';
  }

  static createEmptyPointAsJson() {
    return json.encode(Point.now(0, 0).toJson());
  }

  static createPasscodesAsJson() {
    return json.encode(Passcodes.random(6).toJson());
  }
}

class IncidentServiceMock extends Mock implements IncidentService {
  static IncidentService build(final int count) {
    IncidentServiceMock mock = IncidentServiceMock();
    when(mock.fetch()).thenAnswer((_) => Future.delayed(
          Duration(microseconds: 1),
          () => [for (var i = 1; i <= count; i++) Incident.fromJson(IncidentBuilder.createIncident(i))],
        ));
    return mock;
  }
}
