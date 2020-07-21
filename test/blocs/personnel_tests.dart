import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/personnel_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:async/async.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc()
    ..withUnitBloc()
    ..withPersonnelBloc()
    ..install();

  test(
    'Personnel bloc should be EMPTY and UNSET',
    () async {
      expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD BE unset");
      expect(harness.personnelBloc.repo.map.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.initialState, isA<PersonnelsEmpty>(), reason: "Unexpected personnel state");
      expect(harness.personnelBloc, emits(isA<PersonnelsEmpty>()));
    },
  );

  group('WHEN personnelBloc is ONLINE', () {
    test('SHOULD load personnel', () async {
      // Arrange
      Operation operation = await _prepare(harness, offline: false);
      final person1 = harness.personService.add();
      final person2 = harness.personService.add();
      final affiliation1 = await harness.affiliationService.add(puuid: person1.uuid);
      final affiliation2 = await harness.affiliationService.add(puuid: person2.uuid);
      final personnel1 = harness.personnelService.add(operation.uuid, auuid: affiliation1.uuid);
      final personnel2 = harness.personnelService.add(operation.uuid, auuid: affiliation2.uuid);

      // Act
      List<Personnel> personnel = await harness.personnelBloc.load();

      // Assert
      expect(personnel.length, 3, reason: "SHOULD contain three personnels");
      expect(
        harness.personnelBloc.repo.containsKey(personnel1.uuid),
        isTrue,
        reason: "SHOULD contain personnel ${personnel1.uuid}",
      );
      expect(
        harness.personnelBloc.repo.containsKey(personnel2.uuid),
        isTrue,
        reason: "SHOULD contain personnel ${personnel2.uuid}",
      );
      expectThrough(
        harness.personnelBloc,
        emits(isA<PersonnelsLoaded>()),
      );
    });

    test('SHOULD create personnel and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final personnel = PersonnelBuilder.create();
      final group = StreamGroup.merge([
        ...harness.affiliationBloc.repos.map((repo) => repo.onChanged),
        harness.personnelBloc.repo.onChanged,
      ]);

      final events = [];
      group.listen((transition) {
        if (transition.isRemote) {
          events.add(transition.to.value);
        }
      });

      // Force inverse order successful push
      // by making dependent services slower
      harness.personService.throttle(Duration(milliseconds: 20));
      harness.affiliationService.throttle(Duration(milliseconds: 10));

      // Act
      await harness.personnelBloc.create(personnel);
      await expectLater(
        harness.personnelBloc.repo.onChanged,
        emitsThrough(
          isA<StorageTransition>().having(
            (transition) => transition.isRemote,
            'is remote',
            isTrue,
          ),
        ),
      );

      // Assert service calls
      verify(harness.personService.create(any)).called(2);
      verify(harness.affiliationService.create(any)).called(2);
      verify(harness.personnelService.create(any, any)).called(2);

      // Assert execution order
      expect(
          events,
          orderedEquals([
            // From onboarding
            isA<Personnel>(),
            // From creation
            isA<Person>(),
            isA<Affiliation>(),
            isA<Personnel>(),
          ]));

      // Assert result
      expectStorageStatus(
        harness.personnelBloc.repo.states[personnel.uuid],
        StorageStatus.created,
        remote: true,
      );
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.update(personnel.copyWith(status: PersonnelStatus.onscene));

      // Assert
      verify(harness.personnelService.update(any)).called(1);
      expectStorageStatus(
        harness.personnelBloc.repo.states[personnel.uuid],
        StorageStatus.updated,
        remote: true,
      );
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    test('SHOULD delete personnel and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.delete(personnel.uuid);

      // Assert
      verify(harness.personnelService.delete(any)).called(1);
      expect(
        harness.personnelBloc.repo.states[personnel.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT BE unset");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expectThrough(harness.personnelBloc, isA<PersonnelsUnloaded>());
    });

    test('SHOULD reload one personnel after unload', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()]);
    });

    test('SHOULD load when operation is selected', () async {
      // Arrange
      await _testShouldLoadWhenOperationIsSelected(harness, offline: false);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      await _testShouldReloadWhenOperationIsSwitched(harness, offline: false);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsDeleted(harness, offline: false);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsCancelled(harness, offline: false);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsResolved(harness, offline: false);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsUnloaded(harness, offline: false);
    });
  });

  group('WHEN personnelBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _prepare(harness, offline: true);
      harness.personnelService.add(harness.userBloc.userId);
      harness.personnelService.add(harness.userBloc.userId);

      // Act
      List<Personnel> personnel = await harness.personnelBloc.load();

      // Assert that only user is mobilized
      expect(personnel.length, 1, reason: "SHOULD contain one personnel");
      expectThrough(
        harness.personnelBloc,
        emits(isA<PersonnelsLoaded>()),
      );
    });

    test('SHOULD create personnel with state CREATED', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create();

      // Act
      await harness.personnelBloc.create(personnel);

      // Assert
      expect(
        harness.personnelBloc.repo.states[personnel.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update personnel with state CREATED', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final personnel1 = PersonnelBuilder.create(status: PersonnelStatus.alerted);
      final personnel2 = PersonnelBuilder.create(status: PersonnelStatus.alerted);
      await harness.personnelBloc.create(personnel1);
      await harness.personnelBloc.create(personnel2);
      expect(harness.personnelBloc.repo.length, 3, reason: "SHOULD contain three personnels");

      // Act
      await harness.personnelBloc.update(personnel2.copyWith(status: PersonnelStatus.onscene));

      // Assert
      expect(
        harness.personnelBloc.repo.states[personnel2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(
        harness.personnelBloc.repo[personnel1.uuid].status,
        equals(PersonnelStatus.alerted),
        reason: "SHOULD be status mobilized",
      );
      expect(
        harness.personnelBloc.repo[personnel2.uuid].status,
        equals(PersonnelStatus.onscene),
        reason: "SHOULD be status onscene",
      );
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    test('SHOULD delete local personnel', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.delete(personnel.uuid);

      // Assert that only user is mobilized
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.personnelBloc, isA<PersonnelsUnloaded>());
    });

    test('SHOULD be empty after reload', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()]);
    });

    test('SHOULD load when operation is selected', () async {
      // Arrange
      await _testShouldLoadWhenOperationIsSelected(harness, offline: true);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      await _testShouldReloadWhenOperationIsSwitched(harness, offline: false);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsDeleted(harness, offline: false);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsCancelled(harness, offline: false);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsResolved(harness, offline: false);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsUnloaded(harness, offline: false);
    });
  });
}

Future _testShouldUnloadWhenOperationIsUnloaded(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
  expect(harness.personnelBloc.ouuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.operationsBloc.unload();

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsResolved(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(status: OperationStatus.completed),
  );

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsCancelled(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(
      status: OperationStatus.completed,
      resolution: OperationResolution.cancelled,
    ),
  );

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsDeleted(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  await harness.operationsBloc.delete(operation.uuid);

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldLoadWhenOperationIsSelected(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness, offline: offline, create: false);

  // Act
  final incident = IncidentBuilder.create();
  final operation = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Assert state
  await expectLater(
    harness.personnelBloc,
    emitsThrough(isA<PersonnelCreated>()),
  );
  expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD change to ${operation.uuid}");
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

  // Assert person for onboarded user
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
  expect(affiliation.org?.uuid, isNull);
  expect(affiliation.div?.uuid, isNull);
  expect(affiliation.dep?.uuid, isNull);
  expect(affiliation.person.uuid, person.uuid);
  expect(affiliation.type, AffiliationType.volunteer);
  expect(affiliation.status, AffiliationStandbyStatus.available);

  // Assert personnel for onboarded user
  final personnels = harness.personnelBloc.findUser(harness.userId);
  expect(personnels, isNotEmpty, reason: "SHOULD contain personnel with userId ${harness.userId}");
  final personnel = personnels.first;
  expect(personnel.fname, user.fname);
  expect(personnel.lname, user.lname);
  expect(personnel.phone, user.phone);
  expect(personnel.email, user.email);
  expect(personnel.userId, user.userId);
  expect(personnel.person, person);
}

Future _testShouldReloadWhenOperationIsSwitched(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  final incident = IncidentBuilder.create();
  final operation2 = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Assert
  await expectThroughInOrderLater(
    harness.personnelBloc,
    [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()],
  );
  expect(harness.personnelBloc.ouuid, operation2.uuid, reason: "SHOULD change to ${operation2.uuid}");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

/// Prepare blocs for testing
Future<Operation> _prepare(BlocTestHarness harness, {@required bool offline, bool create = true}) async {
  await harness.userBloc.login(
    username: harness.username,
    password: harness.password,
  );

  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }

  // Wait for UserOnboarded
  await expectThroughLater(
    harness.affiliationBloc,
    emits(isA<UserOnboarded>()),
    close: false,
  );

  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

  if (!create) {
    return Future.value();
  }

  // Create operation
  final incident = IncidentBuilder.create();
  final operation = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Prepare OperationBloc
  await expectThroughLater(harness.operationsBloc, emits(isA<OperationSelected>()), close: false);
  expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD NOT be unset");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelsLoaded>()), close: false);
  expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on operation ${operation.uuid}");

  return operation;
}
