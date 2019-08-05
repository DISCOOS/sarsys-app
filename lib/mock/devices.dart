import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';

class DeviceBuilder {
  static createDeviceAsJson(String id, DeviceType type, String number, Point center) {
    final rnd = math.Random(1);
    final location = createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
    return json.decode('{'
        '"id": "$id",'
        '"type": "${enumName(type)}",'
        '"number": "$number",'
        '"location": $location'
        '}');
  }

  static double nextDouble(rnd, double fraction) {
    return (-100 + rnd.nextInt(200)).toDouble() / 100 * fraction;
  }

  static String createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }
}

class DeviceServiceMock extends Mock implements DeviceService {
  static DeviceService build(final IncidentBloc bloc, final int count) {
    final List<Device> devices = [];
    final DeviceServiceMock mock = DeviceServiceMock();
    final issi = NumberFormat("##");
    when(mock.fetch(any)).thenAnswer((_) async {
      Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.current.ipp;
      if (devices.isEmpty) {
        devices.addAll([
          for (var i = 1; i <= count; i++)
            Device.fromJson(
                DeviceBuilder.createDeviceAsJson("d$i", DeviceType.Tetra, "61001${issi.format(i)}", center)),
        ]);
      }
      return ServiceResponse.ok(body: devices);
    });
    return mock;
  }
}
