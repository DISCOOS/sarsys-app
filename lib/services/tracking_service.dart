import 'dart:async';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;

class TrackingService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController _controller = StreamController.broadcast();

  TrackingService(this.restUrl, this.wsUrl, this.client);

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  /// GET ../incident/{incidentId}/tracking
  Future<ServiceResponse<List<Tracking>>> fetch(incidentId) async {
    // TODO: Implement fetch tracking
    throw "Not implemented";
  }

  /// POST ../incident/{incidentId}/tracking
  Future<ServiceResponse<Tracking>> create(String unitId, List<String> devices) async {
    // TODO: Implement create tracking
    throw "Not implemented";
  }

  Future<ServiceResponse<void>> update(Tracking tracking) async {
    // TODO: Implement update tracking
    throw "Not implemented";
  }

  /// DELETE ../units/{unitId}
  Future<ServiceResponse<void>> delete(Tracking unit) async {
    // TODO: Implement delete unit
    throw "Not implemented";
  }

  void dispose() {
    _controller.close();
  }
}

enum TrackingMessageType { TrackingChanged, LocationChanged }

class TrackingMessage {
  final String incidentId;
  final TrackingMessageType type;
  final Map<String, dynamic> json;
  TrackingMessage(this.incidentId, this.type, this.json);
}
