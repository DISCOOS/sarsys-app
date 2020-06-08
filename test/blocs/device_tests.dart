import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/mock/device_service_mock.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc()
    ..withDeviceBloc()
    ..install();

  test(
    'Device bloc should be EMPTY and UNSET',
    () async {
      expect(harness.deviceBloc.ouuid, isNull, reason: "SHOULD BE unset");
      expect(harness.deviceBloc.devices.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.initialState, isA<DevicesEmpty>(), reason: "Unexpected device state");
      expect(harness.deviceBloc, emits(isA<DevicesEmpty>()));
    },
  );

  group('WHEN deviceBloc is ONLINE', () {
    test('SHOULD load devices', () async {
      // Arrange
      harness.connectivity.cellular();
      Operation operation = await _prepare(harness);
      final device1 = harness.deviceService.add(operation.uuid);
      final device2 = harness.deviceService.add(operation.uuid);

      // Act
      List<Device> devices = await harness.deviceBloc.load();

      // Assert
      expect(devices.length, 2, reason: "SHOULD contain two devices");
      expect(
        harness.deviceBloc.repo.containsKey(device1.uuid),
        isTrue,
        reason: "SHOULD contain device ${device1.uuid}",
      );
      expect(
        harness.deviceBloc.repo.containsKey(device2.uuid),
        isTrue,
        reason: "SHOULD contain device ${device2.uuid}",
      );
      expectThrough(harness.deviceBloc, emits(isA<DevicesLoaded>()));
    });

    test('SHOULD create device and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final device = DeviceBuilder.create();

      // Act
      await harness.deviceBloc.create(device);

      // Assert
      verify(harness.deviceService.create(any, any)).called(1);
      expectStorageStatus(
        harness.deviceBloc.repo.states[device.uuid],
        StorageStatus.created,
        remote: true,
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceCreated>());
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final device = harness.deviceService.add(operation.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.update(device.copyWith(type: DeviceType.Tetra));

      // Assert
      verify(harness.deviceService.update(any)).called(1);
      expectStorageStatus(
        harness.deviceBloc.repo.states[device.uuid],
        StorageStatus.updated,
        remote: true,
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceUpdated>());
    });

    test('SHOULD delete device and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final device = harness.deviceService.add(operation.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.delete(device.uuid);

      // Assert
      verify(harness.deviceService.delete(any)).called(1);
      expect(
        harness.deviceBloc.repo.states[device.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.isUnset, isFalse, reason: "SHOULD NOT BE unset");
      expect(harness.deviceBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      harness.deviceService.add(operation.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expectThrough(harness.deviceBloc, isA<DevicesUnloaded>());
    });

    test('SHOULD reload one device after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final device = harness.deviceService.add(operation.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await harness.deviceBloc.load();

      // Assert
      expect(harness.deviceBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThroughInOrder(harness.deviceBloc, [isA<DevicesUnloaded>(), isA<DevicesLoaded>()]);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
    });
  });

  group('WHEN deviceBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      harness.deviceService.add(harness.userBloc.userId);
      harness.deviceService.add(harness.userBloc.userId);

      // Act
      List<Device> devices = await harness.deviceBloc.load();

      // Assert
      expect(devices.length, 0, reason: "SHOULD NOT contain devices");
      expect(harness.deviceBloc, emits(isA<DevicesLoaded>()));
    });

    test('SHOULD create device with state CREATED', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final device = DeviceBuilder.create();

      // Act
      await harness.deviceBloc.create(device);

      // Assert
      expectStorageStatus(
        harness.deviceBloc.repo.states[device.uuid],
        StorageStatus.created,
        remote: false,
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expectThrough(harness.deviceBloc, isA<DeviceCreated>());
    });

    test('SHOULD update device with state CREATED', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final device1 = DeviceBuilder.create();
      final device2 = DeviceBuilder.create();
      await harness.deviceBloc.create(device1);
      await harness.deviceBloc.create(device2);
      expect(harness.deviceBloc.repo.length, 2, reason: "SHOULD contain two devices");

      // Act
      await harness.deviceBloc.update(device2.copyWith(type: DeviceType.Tetra));

      // Assert
      expectStorageStatus(
        harness.deviceBloc.repo.states[device2.uuid],
        StorageStatus.created,
        remote: false,
      );
      expect(harness.deviceBloc.repo[device1.uuid].type, equals(DeviceType.App), reason: "SHOULD be type App");
      expect(harness.deviceBloc.repo[device2.uuid].type, equals(DeviceType.Tetra), reason: "SHOULD be type Tetra");
      expectThrough(harness.deviceBloc, isA<DeviceUpdated>());
    });

    test('SHOULD delete local device', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.delete(device.uuid);

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.deviceBloc, isA<DeviceDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.deviceBloc, isA<DevicesUnloaded>());
    });

    test('SHOULD be empty after reload', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await harness.deviceBloc.load();

      // Assert
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expectThroughInOrder(harness.deviceBloc, [isA<DevicesUnloaded>(), isA<DevicesLoaded>()]);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
    });
  });
}

Future _testShouldUnloadWhenOperationIsUnloaded(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
  expect(harness.deviceBloc.ouuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.operationsBloc.unload();

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsResolved(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(status: OperationStatus.completed),
  );

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsCancelled(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(
      status: OperationStatus.completed,
      resolution: OperationResolution.cancelled,
    ),
  );

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsDeleted(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.operationsBloc.delete(operation.uuid);

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldReloadWhenOperationIsSwitched(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  final incident = IncidentBuilder.create();
  final operation2 = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Assert
  await expectThroughInOrderLater(
    harness.deviceBloc,
    [isA<DevicesUnloaded>(), isA<DevicesLoaded>()],
  );
  expect(harness.deviceBloc.ouuid, operation2.uuid, reason: "SHOULD change to ${operation2.uuid}");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

/// Prepare blocs for testing
Future<Operation> _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

  // Create operation
  final incident = IncidentBuilder.create();
  final operation = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Prepare OperationBloc
  await expectThroughLater(harness.operationsBloc, emits(isA<OperationSelected>()), close: false);
  expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD NOT be unset");

  // Prepare DeviceBloc
  await expectThroughLater(harness.deviceBloc, emits(isA<DevicesLoaded>()), close: false);
  expect(harness.deviceBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.deviceBloc.ouuid, operation.uuid, reason: "SHOULD depend on operation ${operation.uuid}");

  return operation;
}
