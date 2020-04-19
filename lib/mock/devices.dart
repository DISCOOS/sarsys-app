import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';

class DeviceBuilder {
  static createDeviceAsJson(String id, DeviceType type, String number, Point center) {
    final rnd = math.Random();
    final point = createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
    return json.decode('{'
        '"id": "$id",'
        '"type": "${enumName(type)}",'
        '"status": "${enumName(DeviceStatus.Attached)}",'
        '"number": "$number",'
        '"point": $point,'
        '"manual": false'
        '}');
  }

  static double nextDouble(rnd, double fraction) {
    return (-100 + rnd.nextInt(200)).toDouble() / 100 * fraction;
  }

  static String createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon, type: PointType.Device).toJson());
  }
}

class DeviceServiceMock extends Mock implements DeviceService {
  final Timer simulator;
  final Map<String, Map<String, Device>> deviceRepo;

  DeviceServiceMock._internal(this.deviceRepo, this.simulator);

  static DeviceService build(final IncidentBloc bloc, final int tetraCount, final int appCount) {
    final rnd = math.Random();
    final Map<String, Map<String, Device>> deviceRepo = {}; // incidentId -> devices
    final Map<String, _DeviceSimulation> simulations = {}; // deviceId -> simulation
    final StreamController<DeviceMessage> controller = StreamController.broadcast();

    final simulator = Timer.periodic(
      Duration(seconds: 2),
      (_) => _progress(
        rnd,
        bloc,
        deviceRepo,
        simulations,
        controller,
      ),
    );
    final DeviceServiceMock mock = DeviceServiceMock._internal(deviceRepo, simulator);
    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);
    // Mock all service methods
    when(mock.load(any)).thenAnswer((_) async {
      final String incidentId = _.positionalArguments[0];
      var devices = deviceRepo[incidentId];
      if (devices == null) {
        devices = deviceRepo.putIfAbsent(incidentId, () => {});
      }
      // Only generate devices for automatically generated incidents
      if (incidentId.startsWith('a:') && devices.isEmpty) {
        Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.selected.ipp?.point;
        _createDevices(DeviceType.Tetra, devices, tetraCount, incidentId, 6114000, center, rnd, simulations);
        _createDevices(DeviceType.App, devices, appCount, incidentId, 91500000, center, rnd, simulations);
      }
      return ServiceResponse.ok(body: devices.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var incidentId = _.positionalArguments[0] as String;
      var devices = deviceRepo[incidentId];
      if (devices == null) {
        devices = deviceRepo.putIfAbsent(incidentId, () => {});
      }
      var device = _.positionalArguments[1] as Device;
      Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.selected.ipp?.point;
      device = _simulate(
        Device(
          id: "$incidentId:d:${randomAlphaNumeric(8).toLowerCase()}",
          type: device.type,
          status: device.status,
          point: device.point ??
              Point.now(
                center.lat + DeviceBuilder.nextDouble(rnd, 0.03),
                center.lon + DeviceBuilder.nextDouble(rnd, 0.03),
                type: PointType.Device,
              ),
          alias: device.alias,
          number: device.number,
        ),
        rnd,
        simulations,
      );
      final d = devices.putIfAbsent(device.id, () => device);
      return ServiceResponse.ok(
        body: d,
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      var device = _.positionalArguments[0] as Device;
      var incident = deviceRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(device.id),
        orElse: null,
      );
      if (incident == null)
        ServiceResponse.notFound(
          message: "Device ${device.id} not found",
        );
      incident.value.update(device.id, (_) => device);
      return ServiceResponse.noContent();
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var device = _.positionalArguments[0] as Device;
      var incident = deviceRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(device.id),
        orElse: null,
      );
      if (incident == null)
        ServiceResponse.notFound(
          message: "Device ${device.id} not found",
        );
      incident.value.remove(device.id);
      return ServiceResponse.noContent();
    });
    return mock;
  }

  static void _createDevices(
    DeviceType type,
    Map<String, Device> devices,
    int count,
    String incidentId,
    int number,
    Point center,
    math.Random rnd,
    Map<String, _DeviceSimulation> simulations,
  ) {
    final prefix = enumName(type).substring(0, 1).toLowerCase();
    return devices.addAll({
      for (var i = 1; i <= count; i++)
        "$incidentId:d:$prefix:$i": _simulate(
          Device.fromJson(
            DeviceBuilder.createDeviceAsJson(
              "$incidentId:d:$prefix:$i",
              type,
              "${++number % 10 == 0 ? ++number : number}",
              center,
            ),
          ),
          rnd,
          simulations,
        ),
    });
  }

  static Device _simulate(
    Device device,
    math.Random rnd,
    Map<String, _DeviceSimulation> simulations,
  ) {
    final simulation = _DeviceSimulation(
      id: device.id,
      point: device.point,
      steps: 16,
      delta: DeviceBuilder.nextDouble(rnd, 0.02),
    );
    simulations.update(device.id, (_) => simulation, ifAbsent: () => simulation);
    return device;
  }

  static void _progress(
    math.Random rnd,
    IncidentBloc bloc,
    Map<String, Map<String, Device>> devicesMap,
    Map<String, _DeviceSimulation> simulations,
    StreamController<DeviceMessage> controller,
  ) {
    final incidentId = bloc.selected?.uuid;
    if (incidentId != null) {
      final devices = devicesMap[incidentId].values.toList()..shuffle();
      // only update 10% each iteration
      final min = math.min(math.max((devices.length * 0.2).toInt(), 1), 3);
      devices.take(min).forEach((device) {
        if (simulations.containsKey(device.id)) {
          var simulation = simulations[device.id];
          var point = simulation.progress(rnd.nextDouble() * 20.0);
          device = device.cloneWith(
            point: point,
          );
          devicesMap[incidentId].update(
            device.id,
            (_) => device,
            ifAbsent: () => device,
          );
          controller.add(
            DeviceMessage(
              duuid: device.id,
              type: DeviceMessageType.LocationChanged,
              json: device.toJson(),
            ),
          );
        }
      });
    }
  }
}

class _DeviceSimulation {
  final String id;
  final int steps;
  final double delta;

  int current;
  Point point;

  _DeviceSimulation({this.delta, this.id, this.point, this.steps}) : current = 0;

  Point progress(double acc) {
    var leg = ((current / 4.0) % 4 + 1).toInt();
    switch (leg) {
      case 1:
        point = Point.now(
          point.lat,
          point.lon + delta / steps,
          acc: acc,
          type: PointType.Device,
        );
        break;
      case 2:
        point = Point.now(
          point.lat - delta / steps,
          point.lon,
          acc: acc,
          type: PointType.Device,
        );
        break;
      case 3:
        point = Point.now(
          point.lat,
          point.lon - delta / steps,
          acc: acc,
          type: PointType.Device,
        );
        break;
      case 4:
        point = Point.now(
          point.lat + delta / steps,
          point.lon,
          acc: acc,
          type: PointType.Device,
        );
        break;
    }
    current = (current + 1) % steps;
    return point;
  }
}
