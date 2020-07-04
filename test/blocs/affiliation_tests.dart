import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

const UNTRUSTED = 'username';
const PASSWORD = 'password';

void main() async {
  final harness = BlocTestHarness()
    ..withAffiliationBloc(
      username: UNTRUSTED,
      password: PASSWORD,
      authenticated: false,
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
      expect(harness.affiliationBloc, emits(isA<UserOnboarded>()));
    },
  );

  test(
    'Affiliation bloc should unload when user is logged out',
    () async {
      // Arrange
      await _authenticate(harness);

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
      await expectThroughLater(harness.affiliationBloc, emits(isA<UserOnboarded>()));
    },
  );

  group('WHEN AffiliationBloc is ONLINE', () {
    test('SHOULD load from backend', () async {
      // Arrange
      harness.connectivity.cellular();
      await _authenticate(harness);
      await _seed(harness);

      // Act
      await harness.affiliationBloc.load();

      // Assert numbers
      expect(harness.affiliationBloc.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc.deps.length, 2, reason: "SHOULD contain 2 departments");
      expect(harness.affiliationBloc.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");

      // Assert direct queries
      final query = harness.affiliationBloc.query();
      expect(query.organisations.length, 2, reason: "SHOULD contain 2 organisations");
      expect(query.divisions.length, 2, reason: "SHOULD contain 2 divisions");
      expect(query.departments.length, 2, reason: "SHOULD contain 2 departments");
      expect(query.entities.length, 6, reason: "SHOULD contain 6 entities");
      expect(query.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");
      expect(query.persons.length, 2, reason: "SHOULD contain 2 persons");

      // Assert untyped queries
      expect(query.find().length, 10, reason: "SHOULD contain 10 aggregates");

      // Assert typed queries
      expect(query.find<Organisation>().length, 2, reason: "SHOULD contain 2 organisations");
      expect(query.find<Division>().length, 2, reason: "SHOULD contain 2 divisions");
      expect(query.find<Department>().length, 2, reason: "SHOULD contain 2 departments");
      expect(query.find<Affiliation>().length, 2, reason: "SHOULD contain 2 affiliations");
      expect(query.find<Person>().length, 2, reason: "SHOULD contain 2 persons");
      expect(
        query.find(types: [Organisation, Division, Department]).length,
        6,
        reason: "SHOULD contain 6 entities",
      );

      await expectThroughLater(
        harness.affiliationBloc,
        emits(isA<AffiliationsLoaded>()),
        close: false,
      );
    });
  });

  group('WHEN AffiliationBloc is OFFLINE', () {
    test('SHOULD initially load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);
      await _seed(harness);
      harness.connectivity.offline();
      reset(harness.organisationService);

      // Act
      await harness.affiliationBloc.load();

      // Assert interactions
      verifyZeroInteractions(harness.organisationService);

      // Assert numbers
      expect(harness.affiliationBloc.orgs.length, 0, reason: "SHOULD contain 0 organisations");
      expect(harness.affiliationBloc.divs.length, 0, reason: "SHOULD contain 0 divisions");
      expect(harness.affiliationBloc.deps.length, 0, reason: "SHOULD contain 0 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");
    });

    test('SHOULD reload for local storage', () async {
      // Arrange
      await _authenticate(harness);
      await _seed(harness);
      await harness.affiliationBloc.load();
      harness.connectivity.offline();
      reset(harness.organisationService);

      // Act
      await harness.affiliationBloc.load();

      // Assert interactions
      verifyZeroInteractions(harness.organisationService);

      // Assert numbers
      expect(harness.affiliationBloc.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc.deps.length, 2, reason: "SHOULD contain 2 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");
    });
  });
}

Future _seed(BlocTestHarness harness) async {
  final org1 = harness.organisationService.add();
  final org2 = harness.organisationService.add();
  final div1 = harness.divisionService.add(org1.uuid);
  final div2 = harness.divisionService.add(org2.uuid);
  harness.departmentService.add(div1.uuid);
  final dep2 = harness.departmentService.add(div2.uuid);
  final p1 = harness.personService.personRepo.values
      .where(
        (person) => person.userId == harness.userId,
      )
      .first;
  expect(
    harness.affiliationService.affiliationRepo.values.where((affiliation) => affiliation.person.uuid == p1.uuid).first,
    isNotNull,
  );
  final p2 = harness.personService.add(userId: Uuid().v4());
  await harness.affiliationService.add(
    orguuid: org2.uuid,
    divuuid: div2.uuid,
    depuuid: dep2.uuid,
    puuid: p2.uuid,
  );
}

// Authenticate user
// Since 'authenticate = false' is passed
// to Harness to allow for testing of
// initial states and transitions of
// AffiliationBloc, all tests that require
// an authenticated user must call this
Future _authenticate(
  BlocTestHarness harness, {
  bool reset = true,
}) async {
  await harness.userBloc.login(
    username: UNTRUSTED,
    password: PASSWORD,
  );
  // Wait for UserAuthenticated event
  // Wait until organisations are loaded
  await expectThroughLater(
    harness.affiliationBloc,
    emits(isA<UserOnboarded>()),
    close: false,
  );
  if (reset) {
    clearInteractions(harness.organisationService);
  }
}
