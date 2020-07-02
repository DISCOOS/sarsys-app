import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

const UNTRUSTED = 'username';
const PASSWORD = 'password';

void main() async {
  final harness = BlocTestHarness()
    ..withAffiliationBloc(
      username: UNTRUSTED,
      password: PASSWORD,
    )
    ..install();

  test(
    'Affiliation bloc should be load when user is authenticated',
    () async {
      // Arrange
      await _authenticate(harness);

      // Assert
      expect(harness.affiliationBloc.orgs.isEmpty, isTrue, reason: "SHOULD BE empty");
      expect(harness.affiliationBloc.divs.isEmpty, isTrue, reason: "SHOULD BE empty");
      expect(harness.affiliationBloc.deps.isEmpty, isTrue, reason: "SHOULD BE empty");
      expect(harness.affiliationBloc.initialState, isA<AffiliationsEmpty>(), reason: "Unexpected organisation state");
      expect(harness.affiliationBloc, emits(isA<AffiliationsLoaded>()));
    },
  );

  test(
    'Affiliation bloc should unload when user is logged out',
    () async {
      // Arrange
      await _authenticate(harness);
      await expectThroughLater(harness.affiliationBloc, emits(isA<AffiliationsLoaded>()), close: false);

      // Act
      await harness.userBloc.logout();

      // Assert
      await expectThroughLater(harness.affiliationBloc, emits(isA<AffiliationsUnloaded>()));
    },
  );

  test(
    'Affiliation bloc should be reload when user is logged in again',
    () async {
      // Arrange
      await _authenticate(harness);
      await harness.userBloc.logout();
      await expectThroughLater(harness.affiliationBloc, emits(isA<AffiliationsUnloaded>()), close: false);

      // Act
      await _authenticate(harness);

      // Assert
      await expectThroughLater(harness.affiliationBloc, emits(isA<AffiliationsLoaded>()));
    },
  );

  group('WHEN AffiliationBloc is ONLINE', () {
    test('SHOULD load affiliations', () async {
      // Arrange
      harness.connectivity.cellular();
      await _authenticate(harness);
      final org1 = harness.organisationService.add();
      final org2 = harness.organisationService.add();
      final div1 = harness.divisionService.add(org1.uuid);
      final div2 = harness.divisionService.add(org2.uuid);
      harness.departmentService.add(div1.uuid);
      harness.departmentService.add(div2.uuid);

      // Act
      await harness.affiliationBloc.load();

      // Assert
      expect(harness.affiliationBloc.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc.deps.length, 2, reason: "SHOULD contain 2 departments");
      await expectThroughLater(
        harness.affiliationBloc,
        emits(isA<AffiliationsLoaded>()),
        close: false,
      );
    });

    test('SHOULD find all affiliations for given organisation', () async {
      // Arrange
      harness.connectivity.cellular();
      await _authenticate(harness);
      final org1 = harness.organisationService.add();
      final org2 = harness.organisationService.add();
      final div1 = harness.divisionService.add(org1.uuid);
      final div2 = harness.divisionService.add(org2.uuid);
      harness.departmentService.add(div1.uuid);
      harness.departmentService.add(div2.uuid);
      await harness.affiliationBloc.load();
      await expectThroughLater(
        harness.affiliationBloc,
        emits(isA<AffiliationsLoaded>()),
        close: false,
      );

      // Act
      final affiliations = harness.affiliationBloc.affiliations;

      // Assert
      expect(affiliations.length, 6, reason: "SHOULD contain 6 affiliations");
    });
  });

  group('WHEN AffiliationBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      harness.organisationService.add();
      harness.organisationService.add();

      // Act
      List<Organisation> organisations = await harness.affiliationBloc.load();

      // Assert
      verifyZeroInteractions(harness.organisationService);
      expect(organisations.length, 0, reason: "SHOULD NOT contain organisations");
      await expectThroughLater(
        harness.affiliationBloc,
        emits(isA<AffiliationsLoaded>()),
      );
    });
  });
}

// Authenticate user
// Since 'authenticate = false' is passed
// to Harness to allow for testing of
// initial states and transitions of
// AffiliationBloc, all tests that require
// an authenticated user must call this
Future _authenticate(BlocTestHarness harness, {bool reset = true}) async {
  await harness.userBloc.login(username: UNTRUSTED, password: PASSWORD);
  // Wait for UserAuthenticated event
  // Wait until organisations are loaded
  await expectThroughLater(
    harness.affiliationBloc,
    emits(isA<AffiliationsLoaded>()),
    close: false,
  );
  if (reset) {
    clearInteractions(harness.organisationService);
  }
}
