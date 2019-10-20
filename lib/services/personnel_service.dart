import 'dart:async';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;

class PersonnelService {
  final String url;
  final Client client;

  PersonnelService(this.url, this.client);

  /// GET ../personnel
  Future<ServiceResponse<List<Personnel>>> fetch(String incidentId) async {
    // TODO: Implement fetch Personnel
    throw "Not implemented";
  }

  /// POST ../personnel
  Future<ServiceResponse<Personnel>> create(String incidentId, Personnel personnel) async {
    // TODO: Implement create Personnel
    throw "Not implemented";
  }

  /// PUT ../personnel/{PersonnelId}
  Future<ServiceResponse<void>> update(Personnel personnel) async {
    // TODO: Implement update Personnel
    throw "Not implemented";
  }

  /// DELETE ../personnel/{PersonnelId}
  Future<ServiceResponse<void>> delete(Personnel personnel) async {
    // TODO: Implement delete Personnel
    throw "Not implemented";
  }
}
