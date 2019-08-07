import 'dart:async';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;

class DeviceService {
  final String url;
  final Client client;

  DeviceService(this.url, [Client client]) : this.client = client ?? Client();

  /// GET ../devices
  Future<ServiceResponse<List<Device>>> fetch(String incidentId) async {
    // TODO: Implement fetch devices
    throw "Not implemented";
  }

  /// POST ../devices
  Future<ServiceResponse<Device>> create(String incidentId, Device device) async {
    // TODO: Implement create device
    throw "Not implemented";
  }

  /// PUT ../devices/{deviceId}
  Future<ServiceResponse<void>> update(Device device) async {
    // TODO: Implement update device
    throw "Not implemented";
  }

  /// DELETE ../devices/{deviceId}
  Future<ServiceResponse<void>> delete(Device device) async {
    // TODO: Implement delete device
    throw "Not implemented";
  }
}
