import 'dart:async';
import 'package:SarSys/models/Device.dart';
import 'package:http/http.dart' show Client;

class DeviceService {
  final String url;
  final Client client;

  DeviceService(this.url, [Client client]) : this.client = client ?? Client();

  /// GET ../devices
  Future<List<Device>> fetch() async {
    // TODO: Implement fetch devices
    throw "Not implemented";
  }
}
