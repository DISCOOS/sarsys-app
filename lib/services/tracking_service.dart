import 'dart:async';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show Client;

class TrackingService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController<TrackingMessage> _controller = StreamController.broadcast();

  TrackingService(this.restUrl, this.wsUrl, this.client);

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  /// GET ../incident/{iuuid}/tracking
  Future<ServiceResponse<List<Tracking>>> fetch(String uuid) async {
    // TODO: Implement fetch tracking
    throw "Not implemented";
  }

  /// POST ../incident/{iuuid}/tracking
  Future<ServiceResponse<Tracking>> create(String iuuid, Tracking tracking) async {
    // TODO: Implement create unit tracking
    throw "Not implemented";
  }

  /// PATCH ../incident/tracking/{uuid}
  Future<ServiceResponse<Tracking>> update(Tracking tracking) async {
    // TODO: Implement update tracking
    throw "Not implemented";
  }

  /// DELETE ../incident/tracking/{uuid}
  Future<ServiceResponse<void>> delete(Tracking tracking) async {
    // TODO: Implement delete unit
    throw "Not implemented";
  }

  void dispose() {
    _controller.close();
  }
}

enum TrackingMessageType { created, updated, deleted }

class TrackingMessage {
  final String uuid;
  final TrackingMessageType type;
  final Map<String, dynamic> json;
  TrackingMessage(this.uuid, this.type, this.json);

  factory TrackingMessage.from(
    Tracking tracking, {
    @required TrackingMessageType type,
  }) =>
      TrackingMessage(
        tracking.uuid,
        type,
        tracking.toJson(),
      );

  factory TrackingMessage.created(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.created,
        tracking.toJson(),
      );

  factory TrackingMessage.updated(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.updated,
        tracking.toJson(),
      );
  factory TrackingMessage.deleted(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.deleted,
        tracking.toJson(),
      );
}
