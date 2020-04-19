import 'dart:async';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/service.dart';
import 'package:http/http.dart' show Client;

class DeviceService {
  final String wsUrl;
  final String restUrl;
  final Client client;

  final StreamController<DeviceMessage> _controller = StreamController.broadcast();

  /// Get stream of device messages
  Stream<DeviceMessage> get messages => _controller.stream;

  DeviceService(this.restUrl, this.wsUrl, this.client);

  /// GET ../devices
  Future<ServiceResponse<List<Device>>> load(String tuuid) async {
    // TODO: Implement fetch devices
    throw "Not implemented";
  }

  /// POST ../devices
  Future<ServiceResponse<Device>> create(String tuuid, Device device) async {
    // TODO: Implement create device
    throw "Not implemented";
  }

  /// PUT ../devices/{deviceId}
  Future<ServiceResponse<Device>> update(Device device) async {
    // TODO: Implement update device
    throw "Not implemented";
  }

  /// DELETE ../devices/{deviceId}
  Future<ServiceResponse<void>> delete(Device device) async {
    // TODO: Implement delete device
    throw "Not implemented";
  }

  void dispose() {
    _controller.close();
  }
}

enum DeviceMessageType { LocationChanged }

class DeviceMessage {
  final String duuid;
  final DeviceMessageType type;
  final Map<String, dynamic> json;
  DeviceMessage({this.duuid, this.type, this.json});
}
