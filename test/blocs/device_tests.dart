import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc()
    ..withDeviceBloc()
    ..install();

  test(
    'Device bloc should be EMPTY and UNSET',
    () async {
      expect(harness.deviceBloc.iuuid, isNull, reason: "SHOULD BE unset");
      expect(harness.deviceBloc.devices.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.initialState, isA<DevicesEmpty>(), reason: "Unexpected device state");
      await expectExactlyLater(harness.deviceBloc, [isA<DevicesEmpty>()]);
    },
  );

  group('WHEN deviceBloc is ONLINE', () {
    test('SHOULD load devices', () async {
      // Arrange
      harness.connectivity.cellular();
      Incident incident = await _prepare(harness);
      final device1 = harness.deviceService.add(incident.uuid);
      final device2 = harness.deviceService.add(incident.uuid);

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
      final incident = await _prepare(harness);
      final device = DeviceBuilder.create();

      // Act
      await harness.deviceBloc.create(device);

      // Assert
      verify(harness.deviceService.create(any, any)).called(1);
      expect(
        harness.deviceBloc.repo.states[device.uuid].status,
        equals(StorageStatus.pushed),
        reason: "SHOULD HAVE status PUSHED",
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceCreated>());
    });

    test('SHOULD update incident and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final device = harness.deviceService.add(incident.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.update(device.cloneWith(type: DeviceType.Tetra));

      // Assert
      verify(harness.deviceService.update(any)).called(1);
      expect(
        harness.deviceBloc.repo.states[device.uuid].status,
        equals(StorageStatus.pushed),
        reason: "SHOULD HAVE status PUSHED",
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceUpdated>());
    });

    test('SHOULD delete device and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final device = harness.deviceService.add(incident.uuid, type: DeviceType.App);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.delete(device);

      // Assert
      verify(harness.deviceService.delete(any)).called(1);
      expect(
        harness.deviceBloc.repo.states[device.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.isUnset, isFalse, reason: "SHOULD NOT BE unset");
      expect(harness.deviceBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      harness.deviceService.add(incident.uuid, type: DeviceType.App);
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
      final incident = await _prepare(harness);
      final device = harness.deviceService.add(incident.uuid, type: DeviceType.App);
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

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
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
      expect(
        harness.deviceBloc.repo.states[device.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one incident");
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
      await harness.deviceBloc.update(device2.cloneWith(type: DeviceType.Tetra));

      // Assert
      expect(
        harness.deviceBloc.repo.states[device2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
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
      await harness.deviceBloc.delete(device);

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
      harness.connectivity.offline();
      await _prepare(harness);
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await harness.deviceBloc.load();

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThroughInOrder(harness.deviceBloc, [isA<DevicesUnloaded>(), isA<DevicesLoaded>()]);
    });

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
    });
  });
}

Future _testShouldUnloadWhenIncidentIsUnloaded(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
  expect(harness.deviceBloc.iuuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.incidentBloc.unload();

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsResolved(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Resolved),
  );

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsCancelled(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Cancelled),
  );

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsDeleted(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.incidentBloc.delete(incident.uuid);

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
    close: false,
  );
  expect(harness.deviceBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldReloadWhenIncidentIsSwitched(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.App);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  var incident2 = IncidentBuilder.create(harness.userBloc.userId);
  incident2 = await harness.incidentBloc.create(incident2, selected: true);

  // Assert
  await expectThroughInOrderLater(
    harness.deviceBloc,
    [isA<DevicesUnloaded>(), isA<DevicesLoaded>()],
  );
  expect(harness.deviceBloc.iuuid, incident2.uuid, reason: "SHOULD change to ${incident2.uuid}");
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

/// Prepare blocs for testing
Future<Incident> _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

  // Create incident
  var incident = IncidentBuilder.create(harness.userBloc.userId);
  incident = await harness.incidentBloc.create(incident);

  // Prepare IncidentBloc
  await expectThroughLater(harness.incidentBloc, emits(isA<IncidentSelected>()), close: false);
  expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");

  // Prepare DeviceBloc
  await expectThroughLater(harness.deviceBloc, emits(isA<DevicesLoaded>()), close: false);
  expect(harness.deviceBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.deviceBloc.iuuid, incident.uuid, reason: "SHOULD depend on incident ${incident.uuid}");

  return incident;
}
