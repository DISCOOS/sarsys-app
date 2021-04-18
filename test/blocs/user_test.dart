import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withUserBloc()
    ..install();

  test('User SHOULD be UNSET initially', () async {
    // Assert
    expect(harness.userBloc.user, isNull, reason: "UserRepository SHOULD not contain User");
    expect(harness.userBloc.initialState, isA<UserUnset>(), reason: "UserBloc SHOULD be in EMPTY state");
    expectThroughInOrder(harness.userBloc, [isA<UserUnset>()]);
  });

  group('WHEN UserBloc is ONLINE', () {
    test('SHOULD load state as EMPTY and UNSET', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act
      await harness.userBloc.load();
      await expectThroughLater(harness.configBloc, emits(isA<AppConfigInitialized>()));

      // Assert
      expect(harness.userBloc.user, isNull, reason: "SHOULD NOT have user");
      expect(harness.userBloc, emits(isA<UserUnset>()));
      expect(harness.configBloc.config, isA<AppConfig>(), reason: "SHOULD HAVE an AppConfig");
    });

    test('and UNSET, user SHOULD login', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );
      // Assert
      expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
      expect(harness.userBloc.user.isUntrusted, isTrue, reason: "SHOULD BE Untrusted");
      expectThroughInOrder(harness.userBloc, [isA<UserAuthenticating>(), isA<UserAuthenticated>()]);
      await _waitForConfigBloc(harness, StorageStatus.updated);
    });

    test('SHOULD reload user', () async {
      // Arrange
      harness.connectivity.cellular();
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );
      await _waitForConfigBloc(harness, StorageStatus.updated);

      // Act
      await harness.userBloc.load();

      // Assert
      expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
      expect(harness.userBloc.user.isUntrusted, isTrue, reason: "SHOULD BE Untrusted");
      expectThroughInOrder(harness.userBloc, [isA<UserAuthenticated>()]);
    });

    test('and USER token is INVALID, token SHOULD be refreshed', () async {
      // Arrange
      harness.connectivity.cellular();
      harness.userService.setCredentials(
        username: BlocTestHarness.UNTRUSTED,
        maxAge: Duration.zero,
      );
      harness.userService.invalidateToken();
      await harness.userBloc.login(
        userId: BlocTestHarness.USER_ID,
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );
      await expectThroughLater(harness.configBloc, emits(isA<AppConfigLoaded>()));

      final events = <UserState>[];
      harness.userBloc.listen((e) => events.add(e));

      // Act
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );

      // Assert
      verify(harness.userService.refresh(any));
      expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
      expectThroughInOrder(harness.userBloc, [
        isA<AuthTokenRefreshed>(),
      ]);
    });

    test('User SHOULD BE secured using PIN', () async {
      // Arrange
      await _testAnyAuthenticatedSecuredByPin(harness, false);
    });

    test('and UN-TRUSTED User is AUTHENTICATED, securing SHOULD NOT yield trust', () async {
      await _testAuthenticatedAnyUntrustedSecuringShouldNotYieldTrust(harness, false);
    });

    test('and PERSONAL UN-TRUSTED User is AUTHENTICATED, logout SHOULD UNSET and DELETE User', () async {
      await _testAuthenticatedPersonalUntrustedLogoutShouldUnsetAndDelete(harness, false);
    });

    test('and PERSONAL TRUSTED User is AUTHENTICATED, logout SHOULD UNSET User Only', () async {
      await _testAuthenticatedPersonalTrustedLogoutShouldUnsetOnly(harness, false);
    });

    test('and SHARED TRUSTED User is AUTHENTICATED, logout SHOULD UNSET and LOCK User', () async {
      await _testAuthenticatedSharedTrustedLogoutShouldUnsetAndLock(harness, false);
    });
  });

  group('WHEN UserBloc is OFFLINE', () {
    test('and UNSET, User SHOULD throw on login', () async {
      // Arrange
      harness.connectivity.offline();

      // Act
      await expectLater(
        () => harness.userBloc.login(
          username: BlocTestHarness.UNTRUSTED,
          password: BlocTestHarness.PASSWORD,
        ),
        throwsA(isA<UserRepositoryOfflineException>()),
      );

      // Assert
      expect(harness.userBloc.user, isNull, reason: "SHOULD NOT HAVE User");
      expectThroughInOrder(harness.userBloc, [isA<UserBlocIsOffline>()]);
    });

    test('SHOULD reload previous user', () async {
      // Arrange
      harness.connectivity.cellular();
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );
      await expectThroughLater(harness.configBloc, emits(isA<AppConfigLoaded>()));
      final newTalkGroupCatalog = '123456';
      await harness.configBloc.updateWith(talkGroupCatalog: newTalkGroupCatalog);
      await expectThroughLater(harness.configBloc, emits(isA<AppConfigUpdated>()));

      // Act
      harness.connectivity.offline();
      await harness.userBloc.load();

      // Assert
      expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
      expect(harness.userBloc.user.isUntrusted, isTrue, reason: "SHOULD BE Untrusted");
      expectThroughInOrder(harness.userBloc, [isA<UserAuthenticated>()]);
      expect(harness.configBloc.repo.state.status, StorageStatus.updated, reason: "SHOULD HAVE updated status");
      expect(harness.configBloc.repo.state.isRemote, isTrue, reason: "SHOULD HAVE remote state");
      expect(harness.configBloc.repo.backlog.length, 0, reason: "SHOULD have empty backlog");
      expect(harness.configBloc.config.talkGroupCatalog, newTalkGroupCatalog, reason: "SHOULD have unchanged config");
    });

    test('and User token is INVALID, token SHOULD not refresh', () async {
      // Arrange
      harness.connectivity.cellular();
      harness.userService.setCredentials(maxAge: Duration.zero);
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );
      await expectThroughLater(harness.configBloc, emits(isA<AppConfigLoaded>()));

      // Act
      harness.connectivity.offline();
      await harness.userBloc.login(
        username: BlocTestHarness.UNTRUSTED,
        password: BlocTestHarness.PASSWORD,
      );

      // Assert
      verifyNever(harness.userService.refresh(any));
      expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
      expectThroughInOrder(harness.userBloc, [isA<UserAuthenticated>()]);
    });

    test('User SHOULD BE secured using PIN', () async {
      await _testAnyAuthenticatedSecuredByPin(harness, true);
    });

    test('and UN-TRUSTED User is AUTHENTICATED, securing SHOULD NOT yield trust', () async {
      await _testAuthenticatedAnyUntrustedSecuringShouldNotYieldTrust(harness, true);
    });

    test('and PERSONAL UN-TRUSTED User is AUTHENTICATED, logout SHOULD UNSET and DELETE User', () async {
      await _testAuthenticatedPersonalUntrustedLogoutShouldUnsetAndDelete(harness, true);
    });

    test('and PERSONAL TRUSTED User is AUTHENTICATED, logout SHOULD UNSET and LOCK User', () async {
      await _testAuthenticatedPersonalTrustedLogoutShouldUnsetOnly(harness, true);
    });

    test('and SHARED TRUSTED User is AUTHENTICATED, logout SHOULD UNSET and LOCK User', () async {
      await _testAuthenticatedSharedTrustedLogoutShouldUnsetAndLock(harness, true);
    });
  });
}

Future _waitForConfigBloc(BlocTestHarness harness, StorageStatus status) async {
  await expectThroughLater(harness.configBloc, emits(isA<AppConfigLoaded>()));
  await expectStorageStatusLater(
    harness.configBloc.config.uuid,
    harness.configBloc.repo,
    status,
    remote: true,
    key: '${harness.configBloc.config.version}',
  );
  expect(harness.configBloc.repo.backlog.length, 0, reason: "SHOULD have empty backlog");
}

Future _testAnyAuthenticatedSecuredByPin(BlocTestHarness harness, bool offline) async {
  // Arrange
  harness.connectivity.cellular();
  await harness.configBloc.init();
  await harness.userBloc.login(
    username: BlocTestHarness.UNTRUSTED,
    password: BlocTestHarness.PASSWORD,
  );
  if (offline) {
    harness.connectivity.offline();
  }

  // Act - throws when not secured
  await expectLater(
    () => harness.userBloc.lock(),
    throwsA(isA<UserNotSecuredException>()),
  );
  await expectLater(
    () => harness.userBloc.unlock('ABC'),
    throwsA(isA<UserNotSecuredException>()),
  );

  // Act - secure default to locked
  await harness.userBloc.secure('123');

  // Assert - personal mode and locked
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isLocked, isTrue, reason: "SHOULD BE Locked");
  expect(harness.userBloc.isUntrusted, isTrue, reason: "SHOULD NOT BE Trusted");

  // Act - secure as unlocked
  await harness.userBloc.secure('123', locked: false);

  // Assert - personal mode and unlocked
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isUnlocked, isTrue, reason: "SHOULD BE Unlocked");
  expect(harness.userBloc.isUntrusted, isTrue, reason: "SHOULD NOT BE Trusted");

  // Act - secure as unlocked
  await harness.userBloc.secure('123', locked: true);

  // Assert - personal mode and unlocked
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isLocked, isTrue, reason: "SHOULD BE Locked");
  expect(harness.userBloc.isUntrusted, isTrue, reason: "SHOULD NOT BE Trusted");

  // Assert - throws with incorrect pin
  await expectLater(
    () => harness.userBloc.unlock('ABC'),
    throwsA(isA<UserForbiddenException>()),
  );

  // Act - unlock with correct pin
  await harness.userBloc.unlock('123');
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isUnlocked, isTrue, reason: "SHOULD BE Unlocked");
  expect(harness.userBloc.isUntrusted, isTrue, reason: "SHOULD NOT BE Trusted");

  // Act - lock without pin
  await harness.userBloc.lock();
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isLocked, isTrue, reason: "SHOULD BE Locked");
  expect(harness.userBloc.isUntrusted, isTrue, reason: "SHOULD NOT BE Trusted");
  expectThroughInOrder(harness.userBloc, [isA<UserLocked>()]);
}

Future _testAuthenticatedAnyUntrustedSecuringShouldNotYieldTrust(BlocTestHarness harness, bool offline) async {
  // Arrange
  harness.connectivity.cellular();
  await harness.userBloc.login(
    username: BlocTestHarness.UNTRUSTED,
    password: BlocTestHarness.PASSWORD,
  );
  await expectThroughLater(harness.configBloc, emits(isA<AppConfigLoaded>()));
  if (offline) {
    harness.connectivity.offline();
  }

  // Act
  await harness.configBloc.init();
  await harness.userBloc.secure('123');

  // Assert
  expect(harness.userBloc.user, isNotNull, reason: "SHOULD HAVE User");
  expect(harness.userBloc.isLocked, isTrue, reason: "SHOULD BE Locked");
  expect(harness.userBloc.isSecured, isTrue, reason: "SHOULD BE Secured");
  expect(harness.userBloc.isTrusted, isFalse, reason: "SHOULD NOT BE Trusted");
  expectThroughInOrder(harness.userBloc, [isA<UserLocked>()]);
}

Future _testAuthenticatedPersonalUntrustedLogoutShouldUnsetAndDelete(BlocTestHarness harness, bool offline) async {
  // Arrange
  harness.connectivity.cellular();
  await harness.userBloc.login(
    username: BlocTestHarness.UNTRUSTED,
    password: BlocTestHarness.PASSWORD,
  );
  await _waitForConfigBloc(harness, StorageStatus.updated);
  if (offline) {
    harness.connectivity.offline();
  }

  // Act
  await harness.userBloc.logout();

  // Assert
  verify(harness.userService.logout(any));
  expect(harness.userBloc.user, isNull, reason: "SHOULD NOT HAVE User");
  expect(harness.userBloc.repo.get(BlocTestHarness.UNTRUSTED), isNull, reason: "SHOULD DELETE User");
  expectThroughInOrder(harness.userBloc, [isA<UserUnset>()]);
}

Future _testAuthenticatedSharedTrustedLogoutShouldUnsetAndLock(BlocTestHarness harness, bool offline) async {
  // Arrange
  harness.connectivity.cellular();
  harness.userService.setCredentials(username: BlocTestHarness.TRUSTED);
  await harness.configBloc.init();
  await harness.configBloc.updateWith(
    securityMode: SecurityMode.shared,
    trustedDomains: [UserService.toDomain(BlocTestHarness.TRUSTED)],
  );
  await harness.userBloc.login(
    username: BlocTestHarness.TRUSTED,
    password: BlocTestHarness.PASSWORD,
  );
  await harness.userBloc.secure('123', locked: false);
  expect(harness.userBloc.isShared, isTrue, reason: "SHOULD BE Shared");
  expect(harness.userBloc.isTrusted, isTrue, reason: "SHOULD BE Trusted");
  expect(harness.userBloc.isUnlocked, isTrue, reason: "SHOULD BE Unlocked");
  if (offline) {
    harness.connectivity.offline();
  }

  // Act
  await harness.userBloc.logout();

  // Assert
  verify(harness.userService.logout(any));
  expect(harness.userBloc.user, isNull, reason: "SHOULD NOT HAVE User");
  expect(harness.userBloc.repo.get(harness.userId), isNotNull, reason: "SHOULD NOT DELETE User");
  expect(harness.userBloc.repo.get(harness.userId).security.locked, isTrue, reason: "SHOULD BE Locked");
  expectThroughInOrder(harness.userBloc, [isA<UserUnset>()]);
}

Future _testAuthenticatedPersonalTrustedLogoutShouldUnsetOnly(BlocTestHarness harness, bool offline) async {
  // Arrange
  harness.connectivity.cellular();
  harness.userService.setCredentials(username: BlocTestHarness.TRUSTED);
  await harness.configBloc.init();
  await harness.configBloc.updateWith(
    securityMode: SecurityMode.personal,
    trustedDomains: [UserService.toDomain(BlocTestHarness.TRUSTED)],
  );
  await harness.userBloc.login(
    username: BlocTestHarness.TRUSTED,
    password: BlocTestHarness.PASSWORD,
    userId: BlocTestHarness.USER_ID,
  );
  await harness.userBloc.secure('123', locked: false);
  expect(harness.userBloc.isPersonal, isTrue, reason: "SHOULD BE Personal");
  expect(harness.userBloc.isUnlocked, isTrue, reason: "SHOULD BE Unlocked");
  expect(harness.userBloc.isTrusted, isTrue, reason: "SHOULD BE Trusted");
  if (offline) {
    harness.connectivity.offline();
  }

  // Act
  await harness.userBloc.logout();

  // Assert
  verify(harness.userService.logout(any));
  expect(harness.userBloc.user, isNull, reason: "SHOULD NOT HAVE User");
  expect(harness.userBloc.repo.get(harness.userId), isNotNull, reason: "SHOULD NOT DELETE User");
  expect(harness.userBloc.repo.get(harness.userId).security.locked, isFalse, reason: "SHOULD BE Unlocked");
  expectThroughInOrder(harness.userBloc, [isA<UserUnset>()]);
}
