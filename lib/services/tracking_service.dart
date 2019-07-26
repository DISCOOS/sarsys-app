import 'dart:async';
import 'package:SarSys/models/Tracking.dart';
import 'package:http/http.dart' show Client;

class TrackingService {
  final String url;
  final Client client;

  TrackingService(this.url, this.client);

  /// GET ../api/incident/{incidentId}/tracking
  Future<List<Tracking>> fetch(incidentId) async {
    // TODO: Implement fetch tracking
    throw "Not implemented";
  }

  Future<Tracking> create(String unitId, List<String> devices) async {
    // TODO: Implement create tracking
    throw "Not implemented";
  }

  Future<Tracking> update(Tracking tracking) async {
    // TODO: Implement update tracking
    throw "Not implemented";
  }
}
