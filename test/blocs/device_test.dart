import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import '../mock/device_service_mock.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc(authenticated: true)
    ..withDeviceBloc()
    ..install();

  test('Device bloc should be EMPTY and LOADED', () async {
    expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
    expect(harness.deviceBloc.state, isA<DevicesLoaded>());
  });

  group('WHEN deviceBloc is ONLINE', () {
    test('SHOULD load devices', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);
      final device1 = harness.deviceService.add();
      final device2 = harness.deviceService.add();

      // Act
      final cached = await harness.deviceBloc.load();
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      final fetched = harness.deviceBloc.repo.values;

      // Assert
      expect(cached.length, 0, reason: "Cached SHOULD contain no devices");
      expect(fetched.length, 2, reason: "Fetched SHOULD contain two devices");
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
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
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
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
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
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
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
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesUnloaded>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );
      await harness.deviceBloc.load();
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DevicesLoaded>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
      expect(harness.deviceBloc.repo.containsKey(device.uuid), isTrue, reason: "SHOULD contain device ${device.uuid}");
    });

    test('SHOULD reload when user is switched', () async {
      // Arrange
      await _testShouldReloadWhenUserIsSwitched(harness, offline: false);
    });

    test('SHOULD unload when user is logged out', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenUserIsLoggedOut(harness, offline: false);
    });
  });

  group('WHEN deviceBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _prepare(harness);
      harness.connectivity.offline();
      harness.deviceService.add();
      harness.deviceService.add();

      // Act
      List<Device> devices = await harness.deviceBloc.load();

      // Assert
      expect(devices.length, 0, reason: "SHOULD NOT contain devices");
      expect(harness.deviceBloc.state, isA<DevicesLoaded>());
    });

    test('SHOULD create device with state CREATED', () async {
      // Arrange
      await _prepare(harness);
      harness.connectivity.offline();
      final device = DeviceBuilder.create();

      // Act
      await harness.deviceBloc.create(device);
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DeviceCreated>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expectStorageStatus(
        harness.deviceBloc.repo.states[device.uuid],
        StorageStatus.created,
        remote: false,
      );
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one operation");
    });

    test('SHOULD update device with state CREATED', () async {
      // Arrange
      await _prepare(harness);
      harness.connectivity.offline();
      final device1 = DeviceBuilder.create();
      final device2 = DeviceBuilder.create();
      await harness.deviceBloc.create(device1);
      await harness.deviceBloc.create(device2);
      expect(harness.deviceBloc.repo.length, 2, reason: "SHOULD contain two devices");

      // Act
      await harness.deviceBloc.update(
        device2.copyWith(type: DeviceType.tetra),
      );
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DeviceUpdated>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expectStorageStatus(
        harness.deviceBloc.repo.states[device2.uuid],
        StorageStatus.created,
        remote: false,
      );
      expect(harness.deviceBloc.repo[device1.uuid].type, equals(DeviceType.app), reason: "SHOULD be type App");
      expect(harness.deviceBloc.repo[device2.uuid].type, equals(DeviceType.tetra), reason: "SHOULD be type tetra");
    });

    test('SHOULD delete local device', () async {
      // Arrange
      await _prepare(harness);
      harness.connectivity.offline();
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.delete(device.uuid);
      await expectThroughLater(
        harness.deviceBloc.stream,
        emits(isA<DeviceDeleted>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      await _prepare(harness);
      harness.connectivity.offline();
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
      await _prepare(harness);
      harness.connectivity.offline();
      final device = DeviceBuilder.create();
      await harness.deviceBloc.create(device);
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

      // Act
      await harness.deviceBloc.unload();
      await harness.deviceBloc.load();

      // Assert
      expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");
    });

    test('SHOULD unload when user is logged out', () async {
      // Arrange
      await _testShouldUnloadWhenUserIsLoggedOut(harness, offline: true);
    });
  });
}

Future _testShouldUnloadWhenUserIsLoggedOut(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness);
  if (offline) {
    harness.connectivity.offline();
  }
  final device = DeviceBuilder.create(type: DeviceType.app);
  await harness.deviceBloc.create(device);
  expect(harness.deviceBloc.repo.length, 1, reason: "SHOULD contain one device");

  // Act
  await harness.userBloc.logout();

  // Assert
  await expectThroughLater(
    harness.deviceBloc.stream,
    emits(isA<DevicesUnloaded>()),
  );
  expect(harness.deviceBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.deviceBloc.repo.containsKey(device.uuid),
    isFalse,
    reason: "SHOULD NOT contain device ${device.uuid}",
  );
}

Future _testShouldReloadWhenUserIsSwitched(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness);
  if (offline) {
    harness.connectivity.offline();
  }
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
Future<void> _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");
}
