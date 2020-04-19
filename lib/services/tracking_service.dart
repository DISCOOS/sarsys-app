import 'dart:async';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/service.dart';
import 'package:http/http.dart' show Client;

class TrackingService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController<TrackingMessage> _controller = StreamController.broadcast();

  TrackingService(this.restUrl, this.wsUrl, this.client);

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  /// GET ../incident/{incidentId}/tracking
  Future<ServiceResponse<List<Tracking>>> fetch(String incidentId) async {
    // TODO: Implement fetch tracking
    throw "Not implemented";
  }

  /// POST ../incident/{incidentId}/tracking
  Future<ServiceResponse<Tracking>> create(
    String incidentId, {
    Point point,
    List<String> devices,
    List<String> aggregates,
  }) async {
    // TODO: Implement create unit tracking
    throw "Not implemented";
  }

  /// PATCH ../incident/tracking/{trackingId}
  Future<ServiceResponse<Tracking>> update(Tracking tracking) async {
    // TODO: Implement update tracking
    throw "Not implemented";
  }

  /// DELETE ../incident/tracking/{trackingId}
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
