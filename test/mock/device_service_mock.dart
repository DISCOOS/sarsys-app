import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

class DeviceBuilder {
  static Device create({
    String uuid,
    Position position,
    String number,
    DeviceType type = DeviceType.app,
    DeviceStatus status = DeviceStatus.unavailable,
    bool randomize = false,
  }) {
    return DeviceModel.fromJson(
      createDeviceAsJson(
        uuid ?? Uuid().v4(),
        type ?? DeviceType.app,
        number ?? '1',
        position ?? toPosition(Defaults.origo),
        status ?? DeviceStatus.unavailable,
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
        '"status": "${enumName(status ?? DeviceStatus.unavailable)}",'
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
  final Map<String, StorageState<Device>> devices;

  Device add({
    String uuid,
    Position position,
    String number = '1',
    DeviceType type = DeviceType.app,
    DeviceStatus status = DeviceStatus.unavailable,
  }) {
    final device = DeviceBuilder.create(
      uuid: uuid,
      type: type,
      number: number,
      status: status,
      position: position,
    );
    put(device);
    return device;
  }

  void put(Device device) {
    devices.update(
        device.uuid,
        (state) => state.apply(
              device,
              replace: true,
              isRemote: true,
            ),
        ifAbsent: () => StorageState.created(
              device,
              StateVersion.first,
              isRemote: true,
            ));
  }

  StorageState<Device> remove(uuid) {
    return devices.remove(uuid);
  }

  DeviceServiceMock reset() {
    devices.clear();
    return this;
  }

  DeviceServiceMock._internal(this.devices, this.simulator);

  static DeviceService build(
    OperationBloc bloc, {
    int tetraCount = 0,
    int appCount = 0,
    bool simulate = false,
    List<String> ouuids = const [],
  }) {
    final rnd = math.Random();
    final Map<String, StorageState<Device>> devicesRepo = {}; // devices
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

    // Only generate devices for automatically generated ouuids
    ouuids.forEach((ouuid) {
      if (ouuid.startsWith('a:')) {
        Position center = _toCenter(bloc);
        _createDevices(DeviceType.tetra, devicesRepo, tetraCount, ouuid, 6114000, center, rnd, simulations);
        _createDevices(DeviceType.app, devicesRepo, appCount, ouuid, 91500000, center, rnd, simulations);
      }
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    // Mock all service methods
    when(mock.getList()).thenAnswer((_) async {
      return ServiceResponse.ok(body: devicesRepo.values.toList());
    });

    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Device>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      var device = state.value;
      final duuid = device.uuid;
      Position center = _toCenter(bloc);
      if (simulate) {
        device = _simulate(
          DeviceModel(
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
      _update(devicesRepo, device);
      return ServiceResponse.ok(
        body: devicesRepo[device.uuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Device>;
      final uuid = next.value.uuid;
      if (devicesRepo.containsKey(uuid)) {
        final state = devicesRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        devicesRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: devicesRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Device $uuid not found",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      var state = _.positionalArguments[0] as StorageState<Device>;
      final uuid = state.value.uuid;
      if (devicesRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: devicesRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Device not found: $uuid",
      );
    });
    return mock;
  }

  static StorageState<Device> _update(Map<String, StorageState<Device>> devicesRepo, Device device) =>
      devicesRepo.update(
          device.uuid,
          (state) => state.apply(
                device,
                isRemote: true,
                replace: false,
              ),
          ifAbsent: () => StorageState.created(
                device,
                StateVersion.first,
                isRemote: true,
              ));

  static Position _toCenter(OperationBloc bloc) {
    return bloc.isUnselected
        ? toPosition(Defaults.origo)
        : Position.fromPoint(
            bloc.selected.ipp.point,
            source: PositionSource.manual,
          );
  }

  static void _createDevices(
    DeviceType type,
    Map<String, StorageState<Device>> devices,
    int count,
    String ouuid,
    int number,
    Position center,
    math.Random rnd,
    Map<String, _DeviceSimulation> simulations,
  ) {
    final prefix = enumName(type).substring(0, 1).toLowerCase();
    return devices.addAll({
      for (var i = 1; i <= count; i++)
        "$ouuid:d:$prefix:$i": StorageState.created(
          _simulate(
            DeviceModel.fromJson(
              DeviceBuilder.createDeviceAsJson(
                "$ouuid:d:$prefix:$i",
                type,
                "${++number % 10 == 0 ? ++number : number}",
                center,
                DeviceStatus.unavailable,
                true,
              ),
            ),
            rnd,
            simulations,
          ),
          StateVersion.first,
          isRemote: true,
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
    OperationBloc bloc,
    Map<String, StorageState<Device>> devicesMap,
    Map<String, _DeviceSimulation> simulations,
    StreamController<DeviceMessage> controller,
  ) {
    final devices = devicesMap.values.toList()..shuffle();
    // only update 10% each iteration
    final min = math.min(math.max((devices.length * 0.2).toInt(), 1), 3);
    devices.take(min).forEach((state) {
      var device = state.value;
      if (simulations.containsKey(device.uuid)) {
        var simulation = simulations[device.uuid];
        var position = simulation.progress(rnd.nextDouble() * 20.0);
        device = device.copyWith(
          position: position,
        );
        _update(
          devicesMap,
          device,
        );
        controller.add(
          DeviceMessage(
            device.toJson(),
          ),
        );
      }
    });
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
