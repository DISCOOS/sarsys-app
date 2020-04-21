//import 'package:SarSys/blocs/device_bloc.dart';
//import 'package:SarSys/core/storage.dart';
//import 'package:SarSys/models/Device.dart';
//import 'package:flutter_test/flutter_test.dart';
//import 'package:bloc_test/bloc_test.dart';
//
//import 'harness.dart';
//
//void main() async {
//  final harness = BlocTestHarness()
//    ..withDeviceBloc()
//    ..install();
//
//  test(
//    'Devices SHOULD be EMPTY initially',
//    () async {
//      // Assert
//      expect(harness.configBloc.repo.config, isNull, reason: "DeviceRepository SHOULD not contain Device");
//      expect(harness.configBloc.initialState, isA<DevicesEmpty>(), reason: "DeviceBloc SHOULD be in EMPTY state");
//      await emitsExactly(harness.configBloc, [isA<DevicesEmpty>()], skip: 0);
//    },
//  );
//
//  group('Devices SHOULD initialize', () {
//    test(
//      'with default values online',
//      () async {
//        // Arrange
//        harness.connectivity.cellular();
//
//        // Act
//        await harness.configBloc.init();
//
//        // Assert
//        expect(harness.configBloc.repo.config, isNotNull, reason: "DeviceRepository SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
//        await emitsExactly(harness.configBloc, [isA<DevicesInitialized>()]);
//      },
//    );
//
//    test(
//      'with default values offline',
//      () async {
//        // Arrange
//        harness.connectivity.offline();
//
//        // Act
//        await harness.configBloc.init();
//
//        // Assert
//        expect(harness.configBloc.repo.config, isNotNull, reason: "DeviceRepository SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
//        await emitsExactly(harness.configBloc, [isA<DeviceInitialized>()]);
//      },
//    );
//  });
//
//  group('Devices SHOULD load', () {
//    test(
//      'with default values when online',
//      () async {
//        // Arrange
//        harness.connectivity.cellular();
//
//        // Act
//        await harness.configBloc.load();
//
//        // Assert
//        expect(harness.configBloc.config, isNotNull, reason: "SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
//        await emitsExactly(harness.configBloc, [isA<DeviceLoaded>()]);
//      },
//    );
//
//    test(
//      'with default values when offline',
//      () async {
//        // Arrange
//        harness.connectivity.offline();
//
//        // Act
//        await harness.configBloc.load();
//
//        // Assert
//        expect(harness.configBloc.config, isNotNull, reason: "SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
//        await emitsExactly(harness.configBloc, [isA<DeviceLoaded>()]);
//      },
//    );
//  });
//
//  group('Device SHOULD update', () {
//    test('update values when online', () async {
//      // Arrange
//      harness.connectivity.cellular();
//
//      // Act
//      final oldConfig = await harness.configBloc.load();
//      final newConfig = oldConfig.copyWith(demoRole: 'personnel');
//      final gotConfig = await harness.configBloc.update(demoRole: 'personnel');
//
//      // Assert
//      expect(gotConfig, equals(newConfig), reason: "SHOULD have changed Device");
//      expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE changed state");
//      await emitsExactly(harness.configBloc, [isA<DeviceLoaded>(), isA<DeviceUpdated>()], skip: 0);
//    });
//
//    test('update values when offline', () async {
//      // Arrange
//      harness.connectivity.offline();
//
//      // Act
//      final oldConfig = await harness.configBloc.load();
//      final newConfig = oldConfig.copyWith(demoRole: 'personnel');
//      final gotConfig = await harness.configBloc.update(demoRole: 'personnel');
//
//      // Assert
//      expect(gotConfig, equals(newConfig), reason: "SHOULD have changed Device");
//      expect(harness.configBloc.repo.state.status, StorageStatus.changed, reason: "SHOULD HAVE changed state");
//      await emitsExactly(harness.configBloc, [isA<DeviceLoaded>(), isA<DeviceUpdated>()], skip: 0);
//    });
//  });
//
//  group('Device SHOULD delete', () {
//    test('values when online', () async {
//      // Arrange
//      harness.connectivity.cellular();
//
//      // Act
//      final oldConfig = await harness.configBloc.load();
//      final newConfig = await harness.configBloc.delete();
//
//      // Assert
//      expect(oldConfig, isNotNull, reason: "SHOULD contain Device");
//      expect(newConfig, isNull, reason: "SHOULD NOT contain Device");
//      expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
//      expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE no repository state");
//      await emitsExactly(harness.configBloc, [isA<DeviceLoaded>(), isA<DeviceDeleted>()], skip: 0);
//    });
//
//    test('values when offline', () async {
//      // Arrange
//      harness.connectivity.offline();
//
//      // Act
//      final oldConfig = await harness.configBloc.load();
//      final newConfig = await harness.configBloc.delete();
//
//      // Assert
//      expect(oldConfig, equals(newConfig), reason: "SHOULD return deleted Device");
//      expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
//      expect(harness.configBloc.repo.state.status, StorageStatus.deleted, reason: "SHOULD HAVE deleted state");
//      await emitsExactly(harness.configBloc, [isA<DeviceLoaded>(), isA<DeviceDeleted>()], skip: 0);
//    });
//  });
//
//  group('Device SHOULD transition state', () {
//    test(
//      'from local to remote',
//      () async {
//        // Arrange
//        harness.connectivity.offline();
//        await harness.configBloc.init();
//        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
//        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");
//
//        // Act
//        harness.connectivity.cellular();
//
//        // Assert
//        await expectLater(
//          harness.configBloc.repo.changes.map((state) => state.status),
//          emits(StorageStatus.remote),
//        );
//        expect(harness.configBloc.repo.config, isA<Device>(), reason: "SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
//      },
//    );
//
//    test(
//      'from local to remote',
//      () async {
//        // Arrange
//        harness.connectivity.offline();
//        await harness.configBloc.load();
//        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
//        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");
//
//        // Act
//        harness.connectivity.cellular();
//
//        // Assert
//        await expectLater(
//          harness.configBloc.repo.changes.map((state) => state.status),
//          emits(StorageStatus.remote),
//        );
//        // Assert
//        expect(harness.configBloc.repo.config, isA<Device>(), reason: "SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
//      },
//    );
//
//    test(
//      'from changed to remote',
//      () async {
//        // Arrange
//        harness.connectivity.cellular();
//        await harness.configBloc.load();
//        harness.connectivity.offline();
//        await harness.configBloc.update();
//        expect(harness.configBloc.repo.state.status, StorageStatus.changed, reason: "SHOULD HAVE local state");
//        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");
//
//        // Act
//        harness.connectivity.cellular();
//
//        // Assert
//        await expectLater(
//          harness.configBloc.repo.changes.map((state) => state.status),
//          emits(StorageStatus.remote),
//        );
//        expect(harness.configBloc.repo.config, isA<Device>(), reason: "SHOULD have Device");
//        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
//      },
//    );
//
//    test(
//      'deleted to not ready',
//      () async {
//        // Arrange
//        harness.connectivity.cellular();
//        await harness.configBloc.load();
//        harness.connectivity.offline();
//        await harness.configBloc.delete();
//        expect(harness.configBloc.repo.state.status, StorageStatus.deleted, reason: "SHOULD HAVE deleted state");
//        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");
//
//        // Act
//        harness.connectivity.cellular();
//
//        // Assert
//        await expectLater(
//          harness.configBloc.repo.changes.map((state) => state.status),
//          emits(StorageStatus.remote),
//        );
//        expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
//        expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE have repository state");
//      },
//    );
//  });
//}
