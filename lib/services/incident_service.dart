import 'dart:async';
import 'package:SarSys/models/Incident.dart';
import 'package:http/http.dart' show Client;

class IncidentService {
  final String url;
  final Client client;

  IncidentService(this.url, [Client client]) : this.client = client ?? Client();

  /// GET ../incidents
  Future<List<Incident>> fetch() async {
    // TODO: Implement fetch incidents
    throw "Not implemented";
  }
}
