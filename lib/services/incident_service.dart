import 'dart:async';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;

class IncidentService {
  final String url;
  final Client client;

  IncidentService(this.url, this.client);

  /// GET ../incidents
  Future<ServiceResponse<List<Incident>>> fetch() async {
    // TODO: Implement fetch incidents
    throw "Not implemented";
  }

  /// POST ../incidents
  Future<ServiceResponse<Incident>> create(Incident incident) async {
    // TODO: Implement create incident
    throw "Not implemented";
  }

  /// PUT ../incidents/{incidentId}
  Future<ServiceResponse<void>> update(Incident incident) async {
    // TODO: Implement update incident
    throw "Not implemented";
  }

  /// DELETE ../incidents/{incidentId}
  Future<ServiceResponse<void>> delete(Incident incident) async {
    // TODO: Implement delete incident
    throw "Not implemented";
  }
}
