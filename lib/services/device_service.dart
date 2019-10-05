import 'dart:async';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;

class DeviceService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController _controller = StreamController.broadcast();

  /// Get stream of device messages
  Stream<DeviceMessage> get messages => _controller.stream;

  DeviceService(this.restUrl, this.wsUrl, this.client);

  /// GET ../devices
  Future<ServiceResponse<List<Device>>> fetch(String incidentId) async {
    // TODO: Implement fetch devices
    throw "Not implemented";
  }

  /// POST ../devices
  Future<ServiceResponse<Device>> attach(String incidentId, Device device) async {
    // TODO: Implement attach device
    throw "Not implemented";
  }

  /// PUT ../devices/{deviceId}
  Future<ServiceResponse<void>> update(Device device) async {
    // TODO: Implement update device
    throw "Not implemented";
  }

  /// DELETE ../devices/{deviceId}
  Future<ServiceResponse<void>> detach(Device device) async {
    // TODO: Implement detach device
    throw "Not implemented";
  }

  void dispose() {
    _controller.close();
  }
}

enum DeviceMessageType { LocationChanged }

class DeviceMessage {
  final String deviceId;
  final DeviceMessageType type;
  final Map<String, dynamic> json;
  DeviceMessage(this.deviceId, this.type, this.json);
}
