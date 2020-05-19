import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

class DeviceBuilder {
  static Device create({
    String uuid,
    Position position,
    String number,
    DeviceType type = DeviceType.App,
    DeviceStatus status = DeviceStatus.Unavailable,
    bool randomize = false,
  }) {
    return Device.fromJson(
      createDeviceAsJson(
        uuid ?? Uuid().v4(),
        type ?? DeviceType.App,
        number ?? '1',
        position ?? toPosition(Defaults.origo),
        status ?? DeviceStatus.Unavailable,
        randomize,
      ),
    );
  }

  static Map<String, dynamic> createDeviceAsJson(
    String uuid,
    DeviceType type,
    String number,
    Position position,
    DeviceStatus status,
    bool randomize,
  ) {
    final rnd = math.Random();
    final actual = randomize
        ? createPositionAsJson(
            position.lat + nextDouble(rnd, 0.03),
            position.lon + nextDouble(rnd, 0.03),
          )
        : jsonEncode(position.toJson());
    return json.decode('{'
        '"uuid": "$uuid",'
        '"type": "${enumName(type)}",'
        '"status": "${enumName(status ?? DeviceStatus.Unavailable)}",'
        '"number": "$number",'
        '"position": $actual,'
        '"manual": false'
        '}');
  }

  static double nextDouble(rnd, double fraction) {
    return (-100 + rnd.nextInt(200)).toDouble() / 100 * fraction;
  }

  static String createPositionAsJson(double lat, double lon) {
    return json.encode(Position.now(
      lat: lat,
      lon: lon,
      source: PositionSource.device,
    ).toJson());
  }
}

class DeviceServiceMock extends Mock implements DeviceService {
  final Timer simulator;
  final Map<String, Map<String, Device>> deviceRepo;

  Device add(
    String iuuid, {
    String uuid,
    Position position,
    String number = '1',
    DeviceType type = DeviceType.App,
    DeviceStatus status = DeviceStatus.Unavailable,
  }) {
    final device = DeviceBuilder.create(
      uuid: uuid,
      type: type,
      number: number,
      status: status,
      position: position,
    );
    put(iuuid, device);
    return device;
  }

  void put(String iuuid, Device device) {
    if (deviceRepo.containsKey(iuuid)) {
      deviceRepo[iuuid].putIfAbsent(device.uuid, () => device);
    } else {
      deviceRepo[iuuid] = {device.uuid: device};
    }
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
    List<String> iuuids = const [],
  }) {
    final rnd = math.Random();
    final Map<String, Map<String, Device>> devicesRepo = {}; // iuuid -> devices
    final Map<String, _DeviceSimulation> simulations = {}; // duuid -> simulation
    final StreamController<DeviceMessage> controller = StreamController.broadcast();
    devicesRepo.clear();
    final simulator = simulate
        ? Timer.periodic(
            Duration(seconds: 2),
            (_) => _progress(
              rnd,
              bloc,
              devicesRepo,
              simulations,
              controller,
            ),
          )
        : null;
    final DeviceServiceMock mock = DeviceServiceMock._internal(devicesRepo, simulator);

    // Only generate devices for automatically generated iuuids
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        final devices = devicesRepo.putIfAbsent(iuuid, () => {});
        Position center = _toCenter(bloc);
        _createDevices(DeviceType.Tetra, devices, tetraCount, iuuid, 6114000, center, rnd, simulations);
        _createDevices(DeviceType.App, devices, appCount, iuuid, 91500000, center, rnd, simulations);
      }
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);
    // Mock all service methods
    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var devices = devicesRepo[iuuid];
      if (devices == null) {
        devices = devicesRepo.putIfAbsent(iuuid, () => {});
      }
      return ServiceResponse.ok(body: devices.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var iuuid = _.positionalArguments[0] as String;
      var devices = devicesRepo[iuuid];
      if (devices == null) {
        devices = devicesRepo.putIfAbsent(iuuid, () => {});
      }
      var device = _.positionalArguments[1] as Device;
      final duuid = device.uuid;
      Position center = _toCenter(bloc);
      if (simulate) {
        device = _simulate(
          Device(
            uuid: duuid,
            type: device.type,
            status: device.status,
            position: device.position ??
                Position.now(
                  lat: center.lat + DeviceBuilder.nextDouble(rnd, 0.03),
                  lon: center.lon + DeviceBuilder.nextDouble(rnd, 0.03),
                  source: PositionSource.device,
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
      var incident = devicesRepo.entries.firstWhere(
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
      var incident = devicesRepo.entries.firstWhere(
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

  static Position _toCenter(IncidentBloc bloc) {
    return bloc.isUnset
        ? toPosition(Defaults.origo)
        : Position.fromPoint(
            bloc.selected.ipp.point,
            source: PositionSource.manual,
          );
  }

  static void _createDevices(
    DeviceType type,
    Map<String, Device> devices,
    int count,
    String iuuid,
    int number,
    Position center,
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
              DeviceStatus.Unavailable,
              true,
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
      position: device.position,
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
    if (iuuid != null && devicesMap.containsKey(iuuid)) {
      final devices = devicesMap[iuuid].values.toList()..shuffle();
      // only update 10% each iteration
      final min = math.min(math.max((devices.length * 0.2).toInt(), 1), 3);
      devices.take(min).forEach((device) {
        if (simulations.containsKey(device.uuid)) {
          var simulation = simulations[device.uuid];
          var position = simulation.progress(rnd.nextDouble() * 20.0);
          device = device.cloneWith(
            position: position,
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
  Position position;

  _DeviceSimulation({this.delta, this.uuid, this.position, this.steps}) : current = 0;

  Position progress(double acc) {
    var leg = ((current / 4.0) % 4 + 1).toInt();
    switch (leg) {
      case 1:
        position = Position.now(
          lat: position.lat,
          lon: position.lon + delta / steps,
          acc: acc,
          source: PositionSource.device,
        );
        break;
      case 2:
        position = Position.now(
          lat: position.lat - delta / steps,
          lon: position.lon,
          acc: acc,
          source: PositionSource.device,
        );
        break;
      case 3:
        position = Position.now(
          lat: position.lat,
          lon: position.lon - delta / steps,
          acc: acc,
          source: PositionSource.device,
        );
        break;
      case 4:
        position = Position.now(
          lat: position.lat + delta / steps,
          lon: position.lon,
          acc: acc,
          source: PositionSource.device,
        );
        break;
    }
    current = (current + 1) % steps;
    return position;
  }
}
