import 'package:SarSys/features/app_config/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:flutter/foundation.dart';
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
      await _testAppConfigShouldInitializeWithDefaultValues(
        harness,
        offline: false,
      );
    });

    test('AppConfig SHOULD initialize with default values locally', () async {
      await _testAppConfigShouldInitializeWithDefaultValues(
        harness,
        local: true,
        offline: false,
      );
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
      await _testAppConfigShouldInitializeWithDefaultValues(harness, offline: true);
    });

    test('AppConfig SHOULD initialize with default values locally', () async {
      await _testAppConfigShouldInitializeWithDefaultValues(
        harness,
        local: true,
        offline: true,
      );
    });

    test('AppConfig SHOULD load with default values', () async {
      await _testAppConfigShouldLoadWithDefaultValues(harness, true);
    });

    // This situation simulates partial onboarding
    // offline where second attempt loads local
    // state instead of remote
    //
    test('AppConfig SHOULD reload with default values', () async {
      // Arrange
      await _testAppConfigShouldLoadWithDefaultValues(harness, true);
      // Act and Assert
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
      'from created to pushed on init 1',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.init();
        expect(harness.configBloc.repo.state.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc.repo.state.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.onChanged),
          emits(StorageStatus.created),
        );
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from created to pushed on init with local=true',
      () async {
        // Arrange
        harness.connectivity.cellular();
        final config = await harness.configBloc.init(local: true);
        expect(harness.configBloc.repo.state.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc.repo.state.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have 1 state in backlog");

        // Act
        final keys = await harness.configBloc.repo.commit();

        // Assert
        expect(keys.length, 1, reason: "SHOULD contain 1 key");
        expect(keys.first, config.version, reason: "SHOULD contain config version");
        expect(harness.configBloc.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
        expect(harness.configBloc.repo.backlog.length, 0, reason: "SHOULD have 0 states in backlog");
      },
    );

    test(
      'from created to pushed on load',
      () async {
        // Arrange
        harness.connectivity.offline();
        await harness.configBloc.load();

        expect(harness.configBloc.repo.state.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc.repo.state.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.onChanged),
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
        await harness.configBloc.updateWith();
        expect(harness.configBloc.repo.state.status, StorageStatus.updated, reason: "SHOULD HAVE updated status");
        expect(harness.configBloc.repo.state.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc.repo.onChanged),
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
  final gotConfig = await harness.configBloc.updateWith(demoRole: 'personnel');

  // Assert
  expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
  expectThroughInOrder(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigUpdated>()]);
  if (!offline) {
    await expectLater(
      harness.configBloc.repo.onChanged,
      emitsThrough(
        isA<StorageState<AppConfig>>().having(
          (source) => source.isRemote,
          "Should push to remote",
          isTrue,
        ),
      ),
    );
  }
  expectStorageStatus(
    harness.configBloc.repo.state,
    offline ? StorageStatus.created : StorageStatus.updated,
    remote: !offline,
  );
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
  expectThroughInOrder(
    harness.configBloc,
    [isA<AppConfigLoaded>()],
    close: false,
  );
}

Future _testAppConfigShouldInitializeWithDefaultValues(
  BlocTestHarness harness, {
  @required bool offline,
  bool local = false,
}) async {
  // Arrange
  _setConnectivity(offline, harness);

  // Act
  await harness.configBloc.init(local: local);

  // Assert
  expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
  expectStorageStatus(
    harness.configBloc.repo.state,
    StorageStatus.created,
    remote: !(offline || local),
  );
  expectThroughInOrder(
    harness.configBloc,
    [isA<AppConfigInitialized>().having((event) => event.local, "Should have local=$local ", local)],
  );
}

void _setConnectivity(bool offline, BlocTestHarness harness) {
  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }
}
