import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/mock/device_service_mock.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc(authenticated: true)
    ..withDeviceBloc()
    ..install();

  test(
    'Device bloc should be EMPTY and UNSET',
    () async {
      expect(harness.deviceBloc.devices.length, 0, reason: "SHOULD BE empty");
      expect(harness.deviceBloc.initialState, isA<DevicesEmpty>(), reason: "Unexpected device state");
      expect(harness.deviceBloc, emits(isA<DevicesEmpty>()));
    },
  );

  group('WHEN deviceBloc is ONLINE', () {
    test('SHOULD load devices', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      final device1 = harness.deviceService.add();
      final device2 = harness.deviceService.add();

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
      await _prepare(harness);
      final device = DeviceBuilder.create();

      // Act
      await harness.deviceBloc.create(device);

      // Assert
      await expectStorageStatusLater(
        device.uuid,
        harness.deviceBloc.repo,
        StorageStatus.created,
        remote: true,
      );
      verify(harness.deviceService.create(any)).called(1);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceCreated>());
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      final device = harness.deviceService.add(type: DeviceType.app);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.update(device.copyWith(type: DeviceType.tetra));

      // Assert
      await expectStorageStatusLater(
        device.uuid,
        harness.deviceBloc.repo,
        StorageStatus.updated,
        remote: true,
      );
      verify(harness.deviceService.update(any)).called(1);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThrough(harness.deviceBloc, isA<DeviceUpdated>());
    });

    test('SHOULD delete device and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      final device = harness.deviceService.add(type: DeviceType.app);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.delete(device.uuid);

      // Assert
      await expectStorageStatusLater(
        device.uuid,
        harness.deviceBloc.repo,
        StorageStatus.deleted,
        remote: true,
      );
      verify(harness.deviceService.delete(any)).called(1);
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.deviceBloc, isA<DeviceDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      harness.deviceService.add(type: DeviceType.app);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.deviceBloc, isA<DevicesUnloaded>());
    });

    test('SHOULD reload one device after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      final device = harness.deviceService.add(type: DeviceType.app);
      await harness.deviceBloc.load();
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await harness.deviceBloc.load();

      // Assert
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
      expectThroughInOrder(harness.deviceBloc, [isA<DevicesUnloaded>(), isA<DevicesLoaded>()]);
    });

    test('SHOULD reload when user is switched', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldReloadWhenUserIsSwitched(harness);
    });

    test('SHOULD unload when user is logged out', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenUserIsLoggedOut(harness);
    });
  });

  group('WHEN deviceBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      harness.deviceService.add();
      harness.deviceService.add();

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
      await harness.deviceBloc.update(device2.copyWith(type: DeviceType.tetra));

      // Assert
      expectStorageStatus(
        harness.deviceBloc.repo.states[device2.uuid],
        StorageStatus.created,
        remote: false,
      );
      expect(harness.deviceBloc.repo[device1.uuid].type, equals(DeviceType.app), reason: "SHOULD be type App");
      expect(harness.deviceBloc.repo[device2.uuid].type, equals(DeviceType.tetra), reason: "SHOULD be type tetra");
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

    test('SHOULD unload when user is logged out', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenUserIsLoggedOut(harness);
    });
  });
}

Future _testShouldUnloadWhenUserIsLoggedOut(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.app);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.userBloc.logout();

  // Assert
  await expectThroughLater(
    harness.deviceBloc,
    emits(isA<DevicesUnloaded>()),
  );
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldReloadWhenUserIsSwitched(BlocTestHarness harness) async {
  await _prepare(harness);
  final device = DeviceBuilder.create(type: DeviceType.app);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.userBloc.logout();
  await harness.userBloc.login(
    username: BlocTestHarness.UNTRUSTED,
    password: BlocTestHarness.PASSWORD,
  );

  // Assert
  await expectThroughInOrderLater(
    harness.deviceBloc,
    [isA<DevicesUnloaded>(), isA<DevicesLoaded>()],
  );
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isTrue,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

/// Prepare blocs for testing
Future _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

  // Prepare DeviceBloc
  return await expectThroughLater(harness.deviceBloc, emits(isA<DevicesLoaded>()));
}
