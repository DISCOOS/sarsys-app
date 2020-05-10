import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withConfigBloc()
    ..install();

  test('AppConfig SHOULD be EMPTY initially', () async {
    // Assert
    expect(harness.configBloc.repo.config, isNull, reason: "AppConfigRepository SHOULD not contain AppConfig");
    expect(harness.configBloc.initialState, isA<AppConfigEmpty>(), reason: "AppConfigBloc SHOULD be in EMPTY state");
    expectThroughInOrder(harness.configBloc, [isA<AppConfigEmpty>()]);
  });

  group('WHEN AppConfigBloc is ONLINE', () {
    test('AppConfig SHOULD initialize with default values', () async {
      await _testAppConfigShouldInitializeWithDefaultValues(harness, false);
    });

    test('AppConfig SHOULD load with default values', () async {
      await _testAppConfigShouldLoadWithDefaultValues(harness, false);
    });

    test('AppConfig SHOULD update values', () async {
      // Arrange
      await _testAppConfigShouldUpdateValues(harness, false);
    });

    test('AppConfig SHOULD delete values', () async {
      await _testAppConfigShouldDeleteValues(harness, false);
    });
  });

  group('WHEN AppConfigBloc is OFFLINE', () {
    test('AppConfig SHOULD initialize with default values', () async {
      await _testAppConfigShouldInitializeWithDefaultValues(harness, true);
    });

    test('AppConfig SHOULD load with default values', () async {
      await _testAppConfigShouldLoadWithDefaultValues(harness, true);
    });

    test('AppConfig SHOULD update values', () async {
      // Arrange
      await _testAppConfigShouldUpdateValues(harness, true);
    });

    test('AppConfig SHOULD delete values', () async {
      await _testAppConfigShouldDeleteValues(harness, true);
    });
  });

  group('AppConfig SHOULD transition state', () {
    test(
      'from created to pushed on init',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.init();
        expect(harness.configBloc.repo.state.status, StorageStatus.created, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.changes),
          emits(StorageStatus.created),
        );
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from created to pushed on load',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.load();
        expect(harness.configBloc.repo.state.status, StorageStatus.created, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.changes),
          emits(StorageStatus.created),
        );
        // Assert
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from changed to pushed on update',
      () async {
        // Arrange
        harness.connectivity.cellular();
        await harness.configBloc.load();
        harness.connectivity.offline();
        await harness.configBloc.update();
        expect(harness.configBloc.repo.state.status, StorageStatus.updated, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.changes),
          emits(StorageStatus.updated),
        );
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from created to no state on delete',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.load();

        // Act
        await harness.configBloc.delete();

        // Assert
        expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE no state");
        expect(harness.configBloc.repo.backlog, isEmpty, reason: "SHOULD have no backlog");
      },
    );
  });
}

Future _testAppConfigShouldDeleteValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await harness.configBloc.load();

  // Act
  final newConfig = await harness.configBloc.delete();

  // Assert
  expect(oldConfig, isNotNull, reason: "SHOULD contain AppConfig");
  expect(newConfig, equals(newConfig), reason: "SHOULD equals old AppConfig");
  expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
  expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE NO repository state}");
  expectThroughInOrder(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigDeleted>()]);
}

Future _testAppConfigShouldUpdateValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await harness.configBloc.load();
  final newConfig = oldConfig.copyWith(demoRole: 'personnel');

  // Act
  final gotConfig = await harness.configBloc.update(demoRole: 'personnel');

  // Assert
  expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
  expectStorageStatus(
    harness.configBloc.repo.state,
    offline ? StorageStatus.created : StorageStatus.updated,
    remote: !offline,
  );
  expectThroughInOrder(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigUpdated>()]);
}

Future _testAppConfigShouldLoadWithDefaultValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);

  // Act
  await harness.configBloc.load();

  // Assert
  expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
  expectStorageStatus(
    harness.configBloc.repo.state,
    StorageStatus.created,
    remote: !offline,
  );
  expectThroughInOrder(harness.configBloc, [isA<AppConfigLoaded>()]);
}

Future _testAppConfigShouldInitializeWithDefaultValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);

  // Act
  await harness.configBloc.init();

  // Assert
  expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
  expectStorageStatus(
    harness.configBloc.repo.state,
    StorageStatus.created,
    remote: !offline,
  );
  expectThroughInOrder(harness.configBloc, [isA<AppConfigInitialized>()]);
}

void _setConnectivity(bool offline, BlocTestHarness harness) {
  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }
}
