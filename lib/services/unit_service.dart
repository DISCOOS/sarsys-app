import 'dart:async';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/service.dart';
import 'package:http/http.dart' show Client;

class UnitService {
  final String url;
  final Client client;

  UnitService(this.url, this.client);

  /// GET ../units
  Future<ServiceResponse<List<Unit>>> load(String incidentId) async {
    // TODO: Implement fetch units
    throw "Not implemented";
  }

  /// POST ../units
  Future<ServiceResponse<Unit>> create(String incidentId, Unit unit) async {
    // TODO: Implement create unit
    throw "Not implemented";
  }

  /// PUT ../units/{unitId}
  Future<ServiceResponse<void>> update(Unit unit) async {
    // TODO: Implement update unit
    throw "Not implemented";
  }

  /// DELETE ../units/{unitId}
  Future<ServiceResponse<void>> delete(Unit unit) async {
    // TODO: Implement delete unit
    throw "Not implemented";
  }
}
