import 'dart:async';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/service.dart';
import 'package:http/http.dart' show Client;

class PersonnelService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController<PersonnelMessage> _controller = StreamController.broadcast();

  PersonnelService(this.restUrl, this.wsUrl, this.client);

  /// Get stream of personnel messages
  Stream<PersonnelMessage> get messages => _controller.stream;

  /// GET ../personnel
  Future<ServiceResponse<List<Personnel>>> load(String incidentId) async {
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

  void dispose() {
    _controller.close();
  }
}

enum PersonnelMessageType { PersonnelChanged }

class PersonnelMessage {
  final String puuid;
  final PersonnelMessageType type;
  final Map<String, dynamic> json;
  PersonnelMessage(this.puuid, this.type, this.json);
}
