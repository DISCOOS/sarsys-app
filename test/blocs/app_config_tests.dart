import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withConfigBloc()
    ..install();

  test(
    'AppConfig SHOULD be EMPTY initially',
    () async {
      // Assert
      expect(harness.configBloc.repo.config, isNull, reason: "AppConfigRepository SHOULD not contain AppConfig");
      expect(harness.configBloc.initialState, isA<AppConfigEmpty>(), reason: "AppConfigBloc SHOULD be in EMPTY state");
      await emitsExactly(harness.configBloc, [isA<AppConfigEmpty>()], skip: 0);
    },
  );

  group('AppConfig SHOULD initialize', () {
    test(
      'with default values online',
      () async {
        // Arrange
        harness.connectivity.cellular();

        // Act
        await harness.configBloc.init();

        // Assert
        expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
        await emitsExactly(harness.configBloc, [isA<AppConfigInitialized>()]);
      },
    );

    test(
      'with default values offline',
      () async {
        // Arrange
        harness.connectivity.offline();

        // Act
        await harness.configBloc.init();

        // Assert
        expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
        await emitsExactly(harness.configBloc, [isA<AppConfigInitialized>()]);
      },
    );
  });

  group('AppConfig SHOULD load', () {
    test(
      'with default values when online',
      () async {
        // Arrange
        harness.connectivity.cellular();

        // Act
        await harness.configBloc.load();

        // Assert
        expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE remote state");
        await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>()]);
      },
    );

    test(
      'with default values when offline',
      () async {
        // Arrange
        harness.connectivity.offline();

        // Act
        await harness.configBloc.load();

        // Assert
        expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
        expect(harness.configBloc.repo.state.status, StorageStatus.local, reason: "SHOULD HAVE local state");
        await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>()]);
      },
    );
  });

  group('AppConfig SHOULD update', () {
    test('update values when online', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act
      final oldConfig = await harness.configBloc.load();
      final newConfig = oldConfig.copyWith(demoRole: 'personnel');
      final gotConfig = await harness.configBloc.update(demoRole: 'personnel');

      // Assert
      expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
      expect(harness.configBloc.repo.state.status, StorageStatus.remote, reason: "SHOULD HAVE changed state");
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigUpdated>()], skip: 0);
    });

    test('update values when offline', () async {
      // Arrange
      harness.connectivity.offline();

      // Act
      final oldConfig = await harness.configBloc.load();
      final newConfig = oldConfig.copyWith(demoRole: 'personnel');
      final gotConfig = await harness.configBloc.update(demoRole: 'personnel');

      // Assert
      expect(gotConfig, equals(newConfig), reason: "SHOULD have changed AppConfig");
      expect(harness.configBloc.repo.state.status, StorageStatus.changed, reason: "SHOULD HAVE changed state");
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigUpdated>()], skip: 0);
    });
  });

  group('AppConfig SHOULD delete', () {
    test('values when online', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act
      final oldConfig = await harness.configBloc.load();
      final newConfig = await harness.configBloc.delete();

      // Assert
      expect(oldConfig, isNotNull, reason: "SHOULD contain AppConfig");
      expect(newConfig, isNull, reason: "SHOULD NOT contain AppConfig");
      expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
      expect(harness.configBloc.repo.state, isNull, reason: "SHOULD HAVE no repository state");
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigDeleted>()], skip: 0);
    });

    test('values when offline', () async {
      // Arrange
      harness.connectivity.offline();

      // Act
      final oldConfig = await harness.configBloc.load();
      final newConfig = await harness.configBloc.delete();

      // Assert
      expect(oldConfig, equals(newConfig), reason: "SHOULD return deleted AppConfig");
      expect(harness.configBloc.isReady, isFalse, reason: "SHOULD NOT be ready");
      expect(harness.configBloc.repo.state.status, StorageStatus.deleted, reason: "SHOULD HAVE deleted state");
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>(), isA<AppConfigDeleted>()], skip: 0);
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
