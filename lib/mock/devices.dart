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
import 'package:uuid/uuid.dart';

class DeviceBuilder {
  static Device create({
    String uuid,
    Point center,
    String number,
    DeviceType type = DeviceType.App,
  }) {
    return Device.fromJson(
      createDeviceAsJson(
        uuid ?? Uuid().v4(),
        type ?? DeviceType.App,
        number ?? '1',
        center ?? toPoint(Defaults.origo),
      ),
    );
  }

  static Map<String, dynamic> createDeviceAsJson(
    String uuid,
    DeviceType type,
    String number,
    Point center,
  ) {
    final rnd = math.Random();
    final point = createPointAsJson(
      center.lat + nextDouble(rnd, 0.03),
      center.lon + nextDouble(rnd, 0.03),
    );
    return json.decode('{'
        '"uuid": "$uuid",'
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

  Device add(
    String iuuid, {
    String uuid,
    Point center,
    String number = '1',
    DeviceType type = DeviceType.App,
  }) {
    final device = DeviceBuilder.create(
      uuid: uuid,
      type: type,
      number: number,
      center: center,
    );
    if (deviceRepo.containsKey(iuuid)) {
      deviceRepo[iuuid].putIfAbsent(device.uuid, () => device);
    } else {
      deviceRepo[iuuid] = {device.uuid: device};
    }
    return device;
  }

  List<Device> remove(uuid) {
    final iuuids = deviceRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((iuuid) => deviceRepo[iuuid].remove(uuid))
        .where(
          (device) => device != null,
        )
        .toList();
  }

  DeviceServiceMock reset() {
    deviceRepo.clear();
    return this;
  }

  DeviceServiceMock._internal(this.deviceRepo, this.simulator);

  static DeviceService build(
    IncidentBloc bloc, {
    int tetraCount = 0,
    int appCount = 0,
    bool simulate = false,
  }) {
    final rnd = math.Random();
    final Map<String, Map<String, Device>> deviceRepo = {}; // iuuid -> devices
    final Map<String, _DeviceSimulation> simulations = {}; // duuid -> simulation
    final StreamController<DeviceMessage> controller = StreamController.broadcast();
    deviceRepo.clear();
    final simulator = simulate
        ? Timer.periodic(
            Duration(seconds: 2),
            (_) => _progress(
              rnd,
              bloc,
              deviceRepo,
              simulations,
              controller,
            ),
          )
        : null;
    final DeviceServiceMock mock = DeviceServiceMock._internal(deviceRepo, simulator);
    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);
    // Mock all service methods
    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var devices = deviceRepo[iuuid];
      if (devices == null) {
        devices = deviceRepo.putIfAbsent(iuuid, () => {});
      }
      // Only generate devices for automatically generated incidents
      if (iuuid.startsWith('a:') && devices.isEmpty) {
        Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.selected.ipp?.point;
        _createDevices(DeviceType.Tetra, devices, tetraCount, iuuid, 6114000, center, rnd, simulations);
        _createDevices(DeviceType.App, devices, appCount, iuuid, 91500000, center, rnd, simulations);
      }
      return ServiceResponse.ok(body: devices.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var iuuid = _.positionalArguments[0] as String;
      var devices = deviceRepo[iuuid];
      if (devices == null) {
        devices = deviceRepo.putIfAbsent(iuuid, () => {});
      }
      var device = _.positionalArguments[1] as Device;
      Point center = bloc.isUnset ? toPoint(Defaults.origo) : bloc.selected.ipp?.point;
      if (simulate) {
        device = _simulate(
          Device(
            uuid: "$iuuid:d:${randomAlphaNumeric(8).toLowerCase()}",
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
      }
      final d = devices.putIfAbsent(device.uuid, () => device);
      return ServiceResponse.ok(
        body: d,
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      var device = _.positionalArguments[0] as Device;
      var incident = deviceRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(device.uuid),
        orElse: null,
      );
      if (incident == null)
        ServiceResponse.notFound(
          message: "Device ${device.uuid} not found",
        );
      incident.value.update(device.uuid, (_) => device);
      return ServiceResponse.ok(body: device);
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var device = _.positionalArguments[0] as Device;
      var incident = deviceRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(device.uuid),
        orElse: null,
      );
      if (incident == null)
        ServiceResponse.notFound(
          message: "Device ${device.uuid} not found",
        );
      incident.value.remove(device.uuid);
      return ServiceResponse.noContent();
    });
    return mock;
  }

  static void _createDevices(
    DeviceType type,
    Map<String, Device> devices,
    int count,
    String iuuid,
    int number,
    Point center,
    math.Random rnd,
    Map<String, _DeviceSimulation> simulations,
  ) {
    final prefix = enumName(type).substring(0, 1).toLowerCase();
    return devices.addAll({
      for (var i = 1; i <= count; i++)
        "$iuuid:d:$prefix:$i": _simulate(
          Device.fromJson(
            DeviceBuilder.createDeviceAsJson(
              "$iuuid:d:$prefix:$i",
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
      uuid: device.uuid,
      point: device.point,
      steps: 16,
      delta: DeviceBuilder.nextDouble(rnd, 0.02),
    );
    simulations.update(device.uuid, (_) => simulation, ifAbsent: () => simulation);
    return device;
  }

  static void _progress(
    math.Random rnd,
    IncidentBloc bloc,
    Map<String, Map<String, Device>> devicesMap,
    Map<String, _DeviceSimulation> simulations,
    StreamController<DeviceMessage> controller,
  ) {
    final iuuid = bloc.selected?.uuid;
    if (iuuid != null) {
      final devices = devicesMap[iuuid].values.toList()..shuffle();
      // only update 10% each iteration
      final min = math.min(math.max((devices.length * 0.2).toInt(), 1), 3);
      devices.take(min).forEach((device) {
        if (simulations.containsKey(device.uuid)) {
          var simulation = simulations[device.uuid];
          var point = simulation.progress(rnd.nextDouble() * 20.0);
          device = device.cloneWith(
            point: point,
          );
          devicesMap[iuuid].update(
            device.uuid,
            (_) => device,
            ifAbsent: () => device,
          );
          controller.add(
            DeviceMessage(
              duuid: device.uuid,
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
  final String uuid;
  final int steps;
  final double delta;

  int current;
  Point point;

  _DeviceSimulation({this.delta, this.uuid, this.point, this.steps}) : current = 0;

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
