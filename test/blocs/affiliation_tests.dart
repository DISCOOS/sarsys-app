import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';

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

  group('WHEN AffiliationBloc is initialized', () {
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
      },
    );

    test(
      'SHOULD onboard USER on first load',
      () async {
        // Arrange
        final orguuid = Uuid().v4();
        final divuuid = Uuid().v4();
        final dep = harness.departmentService.add(
          divuuid,
          name: harness.department,
        );
        final div = harness.divisionService.add(
          orguuid,
          name: harness.division,
          departments: [dep.uuid],
        );
        final org = harness.organisationService.add(
          uuid: orguuid,
          divisions: [div.uuid],
        );
        final group = StreamGroup.merge([
          ...harness.affiliationBloc.repos.map((repo) => repo.onChanged),
        ]);

        final events = [];
        group.listen((transition) {
          if (transition.isRemote) {
            events.add(transition.to.value);
          }
        });

        // Force inverse order successful push
        // by making dependent services slower
        harness.personService.throttle(Duration(milliseconds: 10));

        // Act
        await _authenticate(harness);
        await expectLater(
          harness.affiliationBloc.repo.onChanged,
          emitsThrough(
            isA<StorageTransition>().having(
              (transition) => transition.isRemote,
              'is remote',
              isTrue,
            ),
          ),
        );

        // Assert service calls
        verify(harness.personService.create(any)).called(1);
        verify(harness.affiliationService.create(any)).called(1);

        // Assert execution order
        expect(
            events,
            orderedEquals([
              // From onboarding
              isA<Organisation>(),
              isA<Division>(),
              isA<Department>(),
              isA<Person>(),
              isA<Affiliation>(),
            ]));

        // Assert states
        expect(harness.affiliationBloc.orgs.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc.divs.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc.deps.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc.repo.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc.persons.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc.state, isA<UserOnboarded>(), reason: " SHOULD be in UserOnboarded state");
        expect(harness.affiliationBloc, emits(isA<UserOnboarded>()));

        // Assert person
        final user = harness.user;
        final person = harness.affiliationBloc.findUserPerson(userId: harness.userId);
        expect(person, isNotNull, reason: "SHOULD contain person with userId ${harness.userId}");
        expect(person.fname, user.fname);
        expect(person.lname, user.lname);
        expect(person.phone, user.phone);
        expect(person.email, user.email);
        expect(person.userId, user.userId);

        // Assert person
        final affiliation = harness.affiliationBloc.findUserAffiliation(userId: harness.userId);
        expect(affiliation, isNotNull, reason: "SHOULD contain affiliation with userId ${harness.userId}");
        expect(affiliation.org.uuid, org.uuid);
        expect(affiliation.div.uuid, div.uuid);
        expect(affiliation.dep.uuid, dep.uuid);
        expect(affiliation.person.uuid, person.uuid);
        expect(affiliation.type, AffiliationType.member);
        expect(affiliation.status, AffiliationStandbyStatus.available);
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
        await expectThroughLater(
          harness.affiliationBloc,
          emits(isA<AffiliationsUnloaded>()),
        );

        // Act
        await _authenticate(harness);

        // Assert
        await expectThroughLater(harness.affiliationBloc, emits(isA<UserOnboarded>()));
      },
    );
  });

  group('WHEN AffiliationBloc is ONLINE', () {
    test('SHOULD load from backend', () async {
      // Arrange
      harness.connectivity.cellular();
      await _authenticate(harness);
      await _seed(harness, offline: false);

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
      );
    });
  });

  group('WHEN AffiliationBloc is OFFLINE', () {
    test('SHOULD initially load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);

      // One affiliation
      await _seed(harness, offline: true);
      harness.connectivity.offline();
      reset(harness.personService);
      reset(harness.divisionService);
      reset(harness.departmentService);
      reset(harness.affiliationService);
      reset(harness.organisationService);

      // Act
      await harness.affiliationBloc.load();

      // Assert interactions
      verifyZeroInteractions(harness.personService);
      verifyZeroInteractions(harness.divisionService);
      verifyZeroInteractions(harness.departmentService);
      verifyZeroInteractions(harness.affiliationService);
      verifyZeroInteractions(harness.organisationService);

      // Assert numbers
      expect(harness.affiliationBloc.orgs.length, 0, reason: "SHOULD contain 0 organisations");
      expect(harness.affiliationBloc.divs.length, 0, reason: "SHOULD contain 0 divisions");
      expect(harness.affiliationBloc.deps.length, 0, reason: "SHOULD contain 0 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 persons");
      expect(harness.affiliationBloc.affiliates.length, 1, reason: "SHOULD contain 1 affiliates");
    });

    test('SHOULD reload for local storage', () async {
      // Arrange
      await _authenticate(harness);
      await _seed(harness, offline: false);
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

Future _seed(
  BlocTestHarness harness, {
  @required bool offline,
}) async {
  final org1 = harness.organisationService.add();
  final org2 = harness.organisationService.add();
  final div1 = harness.divisionService.add(org1.uuid);
  final div2 = harness.divisionService.add(org2.uuid);
  harness.departmentService.add(div1.uuid);
  final dep2 = harness.departmentService.add(div2.uuid);
  final p1 = harness.affiliationBloc.persons.values
      .where(
        (person) => person.userId == harness.userId,
      )
      .first;
  expect(
    harness.affiliationBloc.repo.values
        .where(
          (affiliation) => affiliation.person.uuid == p1.uuid,
        )
        .firstOrNull,
    isNotNull,
  );
  final p2 = harness.personService.add(userId: Uuid().v4());
  await harness.affiliationService.add(
    // Add remotely only
    storage: !offline,
    puuid: p2.uuid,
    orguuid: org2.uuid,
    divuuid: div2.uuid,
    depuuid: dep2.uuid,
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
  expect(harness.user.userId, equals(harness.userId));
  expect(harness.user.division, equals(harness.division));
  expect(harness.user.department, equals(harness.department));

  // Wait for UserAuthenticated event
  // Wait until organisations are loaded
  await expectThroughLater(
    harness.affiliationBloc,
    emits(isA<UserOnboarded>()),
  );
  if (reset) {
    clearInteractions(harness.organisationService);
  }

  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");
}
