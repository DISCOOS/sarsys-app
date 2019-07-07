import 'dart:async';
import 'package:SarSys/models/Tracking.dart';
import 'package:http/http.dart' show Client;

class TrackingService {
  final String url;
  final Client client;

  TrackingService(this.url, this.client);

  /// GET ../tracking
  Future<List<Tracking>> fetch() async {
    // TODO: Implement fetch tracking
    throw "Not implemented";
  }
}
