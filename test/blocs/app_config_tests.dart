import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withConfigBloc()
    ..install();

  test('AppConfig SHOULD be EMPTY initially', () async {
    // Assert
    expect(harness.configBloc.repo.config, isNull, reason: "AppConfigRepository SHOULD not contain AppConfig");
    expect(harness.configBloc.initialState, isA<AppConfigEmpty>(), reason: "AppConfigBloc SHOULD be in EMPTY state");
    await emitsExactly(harness.configBloc, [isA<AppConfigEmpty>()], skip: 0);
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
      'from local to remote',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.init();
        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          harness.configBloc.repo.changes.map((state) => state.status),
          emits(StorageStatus.remote),
        );
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from local to remote',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.load();
        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          harness.configBloc.repo.changes.map((state) => state.status),
          emits(StorageStatus.remote),
        );
        // Assert
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from changed to remote',
      () async {
        // Arrange
        harness.connectivity.cellular();
        await harness.configBloc.load();
        harness.connectivity.offline();
        await harness.configBloc.update();
        expect(harness.configBloc.repo.state.status, StorageStatus.changed, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          harness.configBloc.repo.changes.map((state) => state.status),
          emits(StorageStatus.remote),
        );
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'deleted to not ready',
      () async {
        // Arrange
        harness.connectivity.cellular();
        await harness.configBloc.load();
        harness.connectivity.offline();
        await harness.configBloc.delete();
        expect(harness.configBloc.repo.state.status, StorageStatus.deleted, reason: "SHOULD HAVE deleted state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          harness.configBloc.repo.changes.map((state) => state.status),
          emits(StorageStatus.remote),
        );
        expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
        expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE have repository state");
      },
    );
  });
}

Future _testAppConfigShouldDeleteValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await harness.configBloc.load();
  final status = offline ? StorageStatus.changed : StorageStatus.remote;

  // Act
  final newConfig = await harness.configBloc.delete();

  // Assert
  expect(oldConfig, isNotNull, reason: "SHOULD contain AppConfig");
  expect(
    newConfig,
    offline ? isNotNull : isNull,
    reason: "SHOULD ${offline ? 'contain AppConfig' : 'NOT contain AppConfig'}",
  );
  expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
  expect(
    harness.configBloc.repo.state,
    offline ? isNotNull : isNull,
    reason: "SHOULD HAVE ${offline ? 'NO repository state' : 'repository state'}",
  );
  await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigDeleted>()], skip: 0);
}

Future _testAppConfigShouldUpdateValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await harness.configBloc.load();
  final newConfig = oldConfig.copyWith(demoRole: 'personnel');
  final status = offline ? StorageStatus.changed : StorageStatus.remote;

  // Act
  final gotConfig = await harness.configBloc.update(demoRole: 'personnel');

  // Assert
  expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
  expect(harness.configBloc.repo.state.status, status, reason: "SHOULD HAVE ${enumName(status)} state");
  await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigUpdated>()], skip: 0);
}

Future _testAppConfigShouldLoadWithDefaultValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final status = offline ? StorageStatus.local : StorageStatus.remote;

  // Act
  await harness.configBloc.load();

  // Assert
  expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
  expect(harness.configBloc.repo.state.status, status, reason: "SHOULD HAVE ${enumName(status)} state");
  await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>()]);
}

Future _testAppConfigShouldInitializeWithDefaultValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final status = offline ? StorageStatus.local : StorageStatus.remote;

  // Act
  await harness.configBloc.init();

  // Assert
  expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
  expect(harness.configBloc.repo.state.status, status, reason: "SHOULD HAVE ${enumName(status)} state");
  await emitsExactly(harness.configBloc, [isA<AppConfigInitialized>()]);
}

void _setConnectivity(bool offline, BlocTestHarness harness) {
  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }
}
