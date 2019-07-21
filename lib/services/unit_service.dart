import 'dart:async';
import 'package:SarSys/models/Unit.dart';
import 'package:http/http.dart' show Client;

class UnitService {
  final String url;
  final Client client;

  UnitService(this.url, this.client);

  /// GET ../units
  Future<List<Unit>> fetch(String incidentId) async {
    // TODO: Implement fetch units
    throw "Not implemented";
  }
}
