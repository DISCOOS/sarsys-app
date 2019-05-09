import 'dart:async';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'dart:convert';
import 'package:http/http.dart' show Client;
import 'package:random_string/random_string.dart';

class IncidentService {
  final String url = '';
  final Client client = Client();

  /// GET ../incidents
  Future<List<Incident>> fetchIncidents() async {
    await Future.delayed(Duration(microseconds: 50));
    return [
      Incident.fromJson(json.decode(_createIncident(2))),
      Incident.fromJson(json.decode(_createIncident(4))),
    ];
  }

  _createIncident(int since) {
    return '{'
        '"id": "${randomAlphaNumeric(16)}",'
        '"name": "Savnet person",'
        '"type": "Lost",'
        '"status": "Handling",'
        '"reference": "2019-RKH-245$since",'
        '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
        '"justification": "Mann, 32 år, økt selvmordsfare.",'
        '"ipp": ${json.encode(Point.now(0, 0).toJson())},'
        '"talkgroups": ['
        '{"name": "RK-RIKS-1", "type": "Tetra"}'
        '],'
        '"passcodes": ${json.encode(Passcodes.random(6).toJson())}'
        '}';
  }
}
