

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withConfigBloc()
    ..install();

  test('AppConfig SHOULD be EMPTY initially', () async {
    // Assert
    expect(harness.configBloc!.repo.config, isNull, reason: "AppConfigRepository SHOULD not contain AppConfig");
    expect(harness.configBloc!.state, isA<AppConfigEmpty>());
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
      'from local to remote on init when online',
      () async {
        // Arrange
        harness.connectivity!.offline();
        await harness.configBloc!.init();
        expect(harness.configBloc!.repo.state!.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc!.repo.state!.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc!.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity!.cellular();

        // Assert
        await expectThroughLater(
          harness.configBloc!.stream,
          emits(isA<AppConfigInitialized>().having(
            (event) {
              return event.isRemote;
            },
            'Should be remote',
            true,
          )),
        );
        expect(harness.configBloc!.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc!.repo.state!.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from created to pushed on init with local=true',
      () async {
        // Arrange
        harness.connectivity!.cellular();
        final config = await (harness.configBloc!.init(local: true) as FutureOr<AppConfig>);
        expect(harness.configBloc!.repo.state!.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc!.repo.state!.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc!.repo.backlog.length, 1, reason: "SHOULD have 1 state in backlog");

        // Act
        final keys = await harness.configBloc!.repo.commit();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc!.repo.onChanged),
          emits(StorageStatus.created),
        );

        // Assert
        expect(keys.length, 1, reason: "SHOULD contain 1 key");
        expect(keys.first, '${config.version}', reason: "SHOULD contain config version");
        expect(harness.configBloc!.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc!.repo.state!.isRemote, isTrue, reason: "SHOULD HAVE remote state");
        expect(harness.configBloc!.repo.backlog.length, 0, reason: "SHOULD have 0 states in backlog");
      },
    );

    test(
      'from created to pushed on load',
      () async {
        // Arrange
        harness.connectivity!.offline();
        await harness.configBloc!.load();

        expect(harness.configBloc!.repo.state!.status, StorageStatus.created, reason: "SHOULD HAVE created status");
        expect(harness.configBloc!.repo.state!.isRemote, isFalse, reason: "SHOULD HAVE local state");
        expect(harness.configBloc!.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity!.cellular();

        // Assert
        await expectLater(
          toStatusChanges(harness.configBloc!.repo.onChanged),
          emits(StorageStatus.created),
        );

        // Assert
        expect(harness.configBloc!.repo.config, isA<AppConfig>(), reason: "SHOULD have AppConfig");
        expect(harness.configBloc!.repo.state!.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from changed to pushed on update',
      () async {
        // Arrange
        harness.connectivity!.cellular();
        await harness.configBloc!.load();
        harness.connectivity!.offline();
        final config = await harness.configBloc!.updateWith(demoRole: 'personnel');

        expect(harness.configBloc!.repo.state!.status, StorageStatus.updated, reason: "SHOULD HAVE updated status");
        expect(harness.configBloc!.repo.state!.isLocal, isTrue, reason: "SHOULD HAVE local state");
        expect(harness.configBloc!.repo.backlog.length, 1, reason: "SHOULD have a backlog");

        // Act
        harness.connectivity!.cellular();

        await expectLater(
          harness.configBloc!.repo.onChanged,
          emitsThrough(
            isA<StorageTransition<AppConfig>>().having(
              (source) {
                return source.to.isRemote;
              },
              "Should change to remote",
              isTrue,
            ),
          ),
        );

        // Assert
        expect(harness.configBloc!.repo.config, equals(config), reason: "SHOULD have AppConfig");
        expect(harness.configBloc!.repo.state!.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      },
    );

    test(
      'from created to no state on delete',
      () async {
        // Arrange
        harness.connectivity!.offline();
        await harness.configBloc!.load();

        // Act
        await harness.configBloc!.delete();

        // Assert
        expect(harness.configBloc!.repo.state, isNull, reason: "SHOULD HAVE no state");
        expect(harness.configBloc!.repo.backlog, isEmpty, reason: "SHOULD have no backlog");
      },
    );
  });
}

Future _testAppConfigShouldDeleteValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await harness.configBloc!.load();

  // Act
  final newConfig = await harness.configBloc!.delete();

  // Assert
  expect(oldConfig, isNotNull, reason: "SHOULD contain AppConfig");
  expect(newConfig, equals(newConfig), reason: "SHOULD equals old AppConfig");
  expect(harness.configBloc!.isReady, isFalse, reason: "SHOULD NOT be ready");
  expectThrough(harness.configBloc, emits(isA<AppConfigDeleted>()));
}

Future _testAppConfigShouldUpdateValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);
  final oldConfig = await (harness.configBloc!.load() as FutureOr<AppConfig>);
  final newConfig = oldConfig.copyWith(demoRole: 'personnel');

  // Act
  final gotConfig = await harness.configBloc!.updateWith(demoRole: 'personnel');

  // Assert
  expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
  expectThrough(harness.configBloc, emits(isA<AppConfigUpdated>()));
  if (!offline) {
    await expectLater(
      harness.configBloc!.repo.onChanged,
      emitsThrough(
        isA<StorageTransition<AppConfig>>().having(
          (source) => source.to.isRemote,
          "Should push to remote",
          isTrue,
        ),
      ),
    );
  }
  expectStorageStatus(
    harness.configBloc!.repo.state!,
    offline ? StorageStatus.created : StorageStatus.updated,
    remote: !offline,
  );
}

Future _testAppConfigShouldLoadWithDefaultValues(BlocTestHarness harness, bool offline) async {
  // Arrange
  _setConnectivity(offline, harness);

  // Act
  await harness.configBloc!.load();

  // Assert
  expect(harness.configBloc!.config, isNotNull, reason: "SHOULD have AppConfig");
  final isRemote = !offline;
  if (isRemote) {
    await expectLater(
      harness.configBloc!.repo.onChanged,
      emitsThrough(isA<StorageTransition>()),
    );
  }

  expectStorageStatus(
    harness.configBloc!.repo.state!,
    StorageStatus.created,
    remote: isRemote,
  );
  expectThroughInOrder(
    harness.configBloc,
    [isA<AppConfigLoaded>()],
    close: false,
  );
}

Future _testAppConfigShouldInitializeWithDefaultValues(
  BlocTestHarness harness, {
  required bool offline,
  bool local = false,
}) async {
  // Arrange
  _setConnectivity(offline, harness);

  // Act
  await harness.configBloc!.init(local: local);
  final isRemote = !(offline || local);
  await expectThroughLater(
    harness.configBloc!.stream,
    emits(isA<AppConfigInitialized>().having(
      (event) {
        return event.isRemote;
      },
      'Should be ${isRemote ? 'remote' : 'local'}',
      isRemote,
    )),
  );

  // Assert
  expectStorageStatus(
    harness.configBloc!.repo.state!,
    StorageStatus.created,
    remote: isRemote,
  );
  expect(
    harness.configBloc!.repo.config,
    isNotNull,
    reason: "AppConfigRepository SHOULD have AppConfig",
  );
}

void _setConnectivity(bool offline, BlocTestHarness harness) {
  if (offline) {
    harness.connectivity!.offline();
  } else {
    harness.connectivity!.cellular();
  }
}
