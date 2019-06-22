import 'dart:convert';

import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';

class DevicesBuilder {
  static createDeviceAsJson(String id, DeviceType type, String number) {
    return json.decode('{'
        '"id": "$id",'
        '"type": "${enumName(type)}",'
        '"number": "$number"'
        '}');
  }
}

class DeviceServiceMock extends Mock implements DeviceService {
  static DeviceService build(final int count) {
    final DeviceServiceMock mock = DeviceServiceMock();
    final issi = NumberFormat("##");
    when(mock.fetch()).thenAnswer((_) async {
      return Future.value([
        for (var i = 1; i <= count; i++)
          Device.fromJson(DevicesBuilder.createDeviceAsJson("u$i", DeviceType.Tetra, "61001${issi.format(i)}")),
      ]);
    });
    return mock;
  }
}
