

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';

import '../mock/affiliation_service_mock.dart';
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
        expect(harness.affiliationBloc!.orgs.isEmpty, isTrue, reason: "SHOULD BE empty");
        expect(harness.affiliationBloc!.divs.isEmpty, isTrue, reason: "SHOULD BE empty");
        expect(harness.affiliationBloc!.deps.isEmpty, isTrue, reason: "SHOULD BE empty");
      },
    );

    test(
      'SHOULD onboard USER on first load',
      () async {
        // Arrange
        final orguuid = Uuid().v4();
        final divuuid = Uuid().v4();
        final dep = harness.departmentService!.add(
          divuuid,
          name: harness.department,
        );
        final div = harness.divisionService!.add(
          orguuid,
          name: harness.division,
          departments: [dep.uuid],
        );
        final org = harness.organisationService!.add(
          uuid: orguuid,
          divisions: [div.uuid],
        );
        final group = StreamGroup.merge([
          ...harness.affiliationBloc!.repos.map((repo) => repo!.onChanged),
        ]);

        final events = [];
        group.listen((transition) {
          if (transition!.isRemote) {
            events.add(transition.to!.value);
          }
        });

        // Force inverse order successful push
        // by making dependent services slower
        harness.personService!.throttle(Duration(milliseconds: 10));

        // Act
        await _authenticate(harness);

        // Assert service calls
        verify(harness.personService!.create(any!)).called(1);
        verify(harness.affiliationService!.create(any!)).called(1);

        // Assert execution order
        expect(
            events,
            unorderedEquals([
              // From onboarding
              isA<Organisation>(),
              isA<Division>(),
              isA<Department>(),
              isA<Affiliation>(),
              isA<Person>(),
            ]));

        // Assert states
        expect(harness.affiliationBloc!.orgs.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc!.divs.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc!.deps.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc!.repo.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc!.persons.values, isNotEmpty, reason: "SHOULD NOT BE empty");
        expect(harness.affiliationBloc!.state, isA<UserOnboarded>(), reason: " SHOULD be in UserOnboarded state");

        // Assert person
        final user = harness.user;
        final person = harness.affiliationBloc!.findUserPerson(userId: harness.userId)!;
        expect(person, isNotNull, reason: "SHOULD contain person with userId ${harness.userId}");
        expect(person.fname, user.fname);
        expect(person.lname, user.lname);
        expect(person.phone, user.phone);
        expect(person.email, user.email);
        expect(person.userId, user.userId);

        // Assert person
        final affiliation = harness.affiliationBloc!.findUserAffiliation(userId: harness.userId)!;
        expect(affiliation, isNotNull, reason: "SHOULD contain affiliation with userId ${harness.userId}");
        expect(affiliation.org!.uuid, org.uuid);
        expect(affiliation.div!.uuid, div.uuid);
        expect(affiliation.dep!.uuid, dep.uuid);
        expect(affiliation.person!.uuid, person.uuid);
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
        await harness.userBloc!.logout();

        // Assert
        await expectThroughLater(
          harness.affiliationBloc!.stream,
          emits(isA<AffiliationsUnloaded>()),
        );
      },
    );

    test(
      'Affiliation bloc should be reload when user is logged in again',
      () async {
        // Arrange
        await _authenticate(harness);
        await harness.userBloc!.logout();
        await expectThroughLater(
          harness.affiliationBloc!.stream,
          emits(isA<AffiliationsUnloaded>()),
        );

        // Act
        await _authenticate(harness, exists: true);

        // Assert
        await expectThroughLater(
          harness.affiliationBloc!.stream,
          emits(isA<AffiliationsLoaded>()),
        );
      },
    );
  });

  group('WHEN AffiliationBloc is ONLINE', () {
    test('SHOULD load from backend', () async {
      // Arrange
      harness.connectivity!.cellular();
      await _authenticate(harness);
      await _seed(harness, offline: false);

      // Act
      await harness.affiliationBloc!.load();
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      // Assert numbers
      expect(harness.affiliationBloc!.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc!.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc!.deps.length, 2, reason: "SHOULD contain 2 departments");
      expect(harness.affiliationBloc!.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");

      // Assert direct queries
      final query = harness.affiliationBloc!.query();
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
    });

    test('SHOULD update person on load', () async {
      // Arrange
      final fname = "fupdated";
      final lname = "lupdated";
      await _authenticate(harness);
      await harness.affiliationBloc!.load();
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc!.repo.length, 1, reason: "SHOULD contain 1 affiliation");
      final person = harness.affiliationBloc!.persons.values.first!;
      expect(harness.affiliationBloc!.repo.values.first!.person, person, reason: "SHOULD be equal");

      // Act
      final updated = await harness.personService!.put(
        person.copyWith(fname: fname, lname: lname),
        storage: false,
      );
      await harness.affiliationBloc!.load();
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc!.repo.length, 1, reason: "SHOULD contain 1 affiliation");

      expect(harness.affiliationBloc!.persons.values.first, updated, reason: "SHOULD be equal");
      expect(harness.affiliationBloc!.repo.values.first!.person, updated, reason: "SHOULD be equal");
    });

    test('SHOULD replace person on conflict', () async {
      // Arrange - person in backend only
      harness.connectivity!.cellular();
      await _authenticate(harness);
      await harness.affiliationBloc!.load();
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      final existing = await harness.personService!.add(userId: "existing", storage: false);
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc!.repo.length, 1, reason: "SHOULD contain 1 affiliation");

      // Act - attempt to onboard new person with 'user_id' user id
      final auuid = Uuid().v4();
      final affiliation = AffiliationBuilder.create(
        uuid: auuid,
        userId: "existing",
      );
      await harness.affiliationBloc!.create(affiliation);
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationCreated>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.affiliationBloc!.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.repo.length, 2, reason: "SHOULD contain 2 affiliations");

      expect(
        harness.affiliationBloc!.persons.find(where: (p) => p!.userId == existing.userId).firstOrNull,
        equals(existing),
        reason: "SHOULD be equal",
      );
      expect(
        harness.affiliationBloc!.repo.find(where: (a) => a!.person!.userId == existing.userId).firstOrNull?.person,
        equals(existing),
        reason: "SHOULD be equal",
      );
    });

    test('SHOULD replace affiliation on conflict', () async {
      // Arrange - person in backend only
      harness.connectivity!.cellular();
      await _authenticate(harness);
      final existing = await _seed(harness, offline: false);
      await harness.affiliationBloc!.load();
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      expect(harness.affiliationBloc!.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.repo.length, 2, reason: "SHOULD contain 2 affiliations");

      // Act - attempt to add another affiliation
      final duplicate = existing.copyWith(uuid: Uuid().v4());
      await harness.affiliationBloc!.create(duplicate);
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationCreated>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.affiliationBloc!.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.repo.length, 2, reason: "SHOULD contain 2 affiliations");
      expect(
        harness.affiliationBloc!.repo[existing.uuid],
        equals(existing),
        reason: "SHOULD contain existing affiliation",
      );
      expect(
        harness.affiliationBloc!.repo.containsKey(duplicate.uuid),
        isFalse,
        reason: "SHOULD not contain duplicate affiliation",
      );
    });
  });

  group('WHEN AffiliationBloc is OFFLINE', () {
    test('SHOULD initially load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);
      await harness.affiliationBloc!.load();
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // One affiliation
      await _seed(harness, offline: true);
      harness.connectivity!.offline();
      reset(harness.personService);
      reset(harness.divisionService);
      reset(harness.departmentService);
      reset(harness.affiliationService);
      reset(harness.organisationService);

      // Act on local storage
      await harness.affiliationBloc!.load();

      // Assert interactions
      verifyZeroInteractions(harness.personService);
      verifyZeroInteractions(harness.divisionService);
      verifyZeroInteractions(harness.departmentService);
      verifyZeroInteractions(harness.affiliationService);
      verifyZeroInteractions(harness.organisationService);

      // Assert numbers
      expect(harness.affiliationBloc!.orgs.length, 0, reason: "SHOULD contain 0 organisations");
      expect(harness.affiliationBloc!.divs.length, 0, reason: "SHOULD contain 0 divisions");
      expect(harness.affiliationBloc!.deps.length, 0, reason: "SHOULD contain 0 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.affiliates.length, 1, reason: "SHOULD contain 2 affiliates");
    });

    test('SHOULD fetch from remote when online', () async {
      // Arrange
      await _authenticate(harness);
      await _seed(harness, offline: true);
      harness.connectivity!.offline();
      await harness.affiliationBloc!.load();
      // Assert async loads
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) {
            return event.isLocal;
          },
          'Should be local',
          isTrue,
        )),
      );
      expect(harness.affiliationBloc!.orgs.length, 0, reason: "SHOULD contain 0 organisations");
      expect(harness.affiliationBloc!.divs.length, 0, reason: "SHOULD contain 0 divisions");
      expect(harness.affiliationBloc!.deps.length, 0, reason: "SHOULD contain 0 departments");
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 1 persons");
      expect(harness.affiliationBloc!.affiliates.length, 1, reason: "SHOULD contain 1 affiliates");

      // Act
      harness.connectivity!.cellular();

      // Assert async loads
      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) {
            return event.isRemote;
          },
          'Should be remote',
          isTrue,
        )),
      );

      // Assert numbers
      expect(harness.affiliationBloc!.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc!.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc!.deps.length, 2, reason: "SHOULD contain 2 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc!.persons.length, 1, reason: "SHOULD contain 1 persons");
      expect(harness.affiliationBloc!.affiliates.length, 1, reason: "SHOULD contain 1 affiliates");
    });

    test('SHOULD reload from local storage', () async {
      // Arrange
      await _authenticate(harness);
      await _seed(harness, offline: false);
      await harness.affiliationBloc!.load();

      await expectThroughLater(
        harness.affiliationBloc!.stream,
        emits(isA<AffiliationsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      harness.connectivity!.offline();
      reset(harness.organisationService);

      // Act
      await harness.affiliationBloc!.load();

      // Assert interactions
      verifyZeroInteractions(harness.organisationService);

      // Assert numbers
      expect(harness.affiliationBloc!.orgs.length, 2, reason: "SHOULD contain 2 organisations");
      expect(harness.affiliationBloc!.divs.length, 2, reason: "SHOULD contain 2 divisions");
      expect(harness.affiliationBloc!.deps.length, 2, reason: "SHOULD contain 2 departments");

      // These are created locally during onboarding and are always there
      expect(harness.affiliationBloc!.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc!.affiliates.length, 2, reason: "SHOULD contain 2 affiliates");
    });
  });
}

Future<Affiliation> _seed(
  BlocTestHarness harness, {
  required bool offline,
}) async {
  final org1 = harness.organisationService!.add();
  final org2 = harness.organisationService!.add();
  final div1 = harness.divisionService!.add(org1.uuid);
  final div2 = harness.divisionService!.add(org2.uuid);
  harness.departmentService!.add(div1.uuid);
  final dep2 = harness.departmentService!.add(div2.uuid);
  final p1 = harness.affiliationBloc!.persons.values
      .where(
        (person) => person!.userId == harness.userId,
      )
      .first;
  expect(
    harness.affiliationBloc!.repo.values
        .where(
          (affiliation) => affiliation!.person!.uuid == p1!.uuid,
        )
        .firstOrNull,
    isNotNull,
  );
  final p2 = await harness.personService!.add(
    uuid: Uuid().v4(),
    userId: Uuid().v4(),
    storage: !offline,
  );
  return await harness.affiliationService!.add(
    puuid: p2.uuid,
    storage: !offline,
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
  bool exists = false,
}) async {
  await harness.userBloc!.login(
    username: UNTRUSTED,
    password: PASSWORD,
  );
  expect(harness.userBloc!.isAuthenticated, isTrue, reason: "SHOULD be authenticated");
  expect(harness.user.userId, equals(harness.userId));
  expect(harness.user.div, equals(harness.division));
  expect(harness.user.dep, equals(harness.department));

  if (!exists) {
    // Wait until user is onboarded remotely
    await expectThroughLater(
      harness.affiliationBloc!.stream,
      emits(isA<UserOnboarded>().having(
        (event) {
          return event.isRemote;
        },
        'Should be remote',
        isTrue,
      )),
    );
    await expectStorageStatusLater(
      harness.affiliationBloc!.persons.values.first!.uuid,
      harness.affiliationBloc!.persons,
      StorageStatus.created,
      remote: true,
    );
    await expectStorageStatusLater(
      harness.affiliationBloc!.repo.values.first!.uuid,
      harness.affiliationBloc!.repo,
      StorageStatus.created,
      remote: true,
    );
  }
  if (reset) {
    clearInteractions(harness.organisationService);
  }
}
