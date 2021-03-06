import 'package:uuid/uuid.dart';
import 'package:async/async.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

import '../mock/incident_service_mock.dart';
import '../mock/personnel_service_mock.dart';
import '../mock/operation_service_mock.dart';

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
      expect(harness.personnelBloc.state, isA<PersonnelsEmpty>());
    },
  );

  group('WHEN personnelBloc is ONLINE', () {
    test('SHOULD load personnel', () async {
      // Arrange
      Operation operation = await _prepare(harness, offline: false);
      final person1 = await harness.personService.add();
      final person2 = await harness.personService.add();
      final affiliation1 = await harness.affiliationService.add(puuid: person1.uuid);
      final affiliation2 = await harness.affiliationService.add(puuid: person2.uuid);
      final personnel1 = harness.personnelService.add(operation.uuid, auuid: affiliation1.uuid);
      final personnel2 = harness.personnelService.add(operation.uuid, auuid: affiliation2.uuid);

      // Act
      List<Personnel> cached = await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      final fetched = harness.personnelBloc.repo.values;

      // Assert
      expect(cached.length, 1, reason: "SHOULD contain one personnel");
      expect(cached.first.person.userId, harness.userId, reason: "SHOULD be onboarded user");
      expect(fetched.length, 3, reason: "SHOULD contain three personnels");
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
    });

    test('SHOULD create personnel and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
      final group = StreamGroup.merge([
        harness.personnelBloc.repo.onChanged,
      ]);

      final aggregates = [];
      group.listen((transition) {
        if (transition.isRemote) {
          aggregates.add(transition.to.value);
        }
      });

      // Act
      await harness.personnelBloc.create(personnel);
      await expectThroughLater(
        StreamGroup.merge([
          harness.personnelBloc.stream,
        ]),
        emitsInAnyOrder([
          isA<PersonnelCreated>().having(
            (event) {
              return event.isRemote;
            },
            'Should be remote',
            isTrue,
          ),
        ]),
      );

      // Assert service calls
      verify(harness.personService.create(any)).called(3);
      verify(harness.affiliationService.create(any)).called(3);
      verify(harness.personnelService.create(any)).called(2);

      // Assert execution order
      expect(
          aggregates,
          unorderedEquals([
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
      expect(
        harness.personnelBloc.repo.containsKey(personnel.uuid),
        isTrue,
        reason: "SHOULD contain personnel ${personnel.uuid}",
      );
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = await harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.update(personnel.copyWith(status: PersonnelStatus.onscene));

      // Assert
      await expectStorageStatusLater(
        personnel.uuid,
        harness.personnelBloc.repo,
        StorageStatus.updated,
        remote: true,
      );
      verify(harness.personnelService.update(any)).called(1);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    // TODO: Better handling of person-data

    test('SHOULD update person on load', () async {
      // Arrange
      final fname = "fupdated";
      final lname = "lupdated";
      await _prepare(harness, offline: false);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain 1 personnel");
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc.repo.length, 1, reason: "SHOULD contain 1 affiliation");
      final person = harness.affiliationBloc.persons.values.first;
      expect(harness.personnelBloc.repo.values.first.person, person, reason: "SHOULD be equal");
      expect(harness.affiliationBloc.repo.values.first.person, person, reason: "SHOULD be equal");

      // Act
      final updated = await harness.personService.put(
        person.copyWith(fname: fname, lname: lname),
        storage: false,
      );
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc.repo.length, 1, reason: "SHOULD contain 1 affiliation");
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain 1 personnel");

      expect(harness.affiliationBloc.persons.values.first, updated, reason: "SHOULD be equal");
      expect(harness.affiliationBloc.repo.values.first.person, updated, reason: "SHOULD be equal");
      expect(harness.personnelBloc.repo.values.first.person, updated, reason: "SHOULD be equal");
    });

    test('SHOULD replace person on conflict', () async {
      // Arrange - person in backend only
      final operation = await _prepare(harness, offline: false);
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      final existing = await harness.personService.add(userId: "existing", storage: false);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain 1 personnel");
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc.repo.length, 1, reason: "SHOULD contain 1 affiliation");

      // Act - attempt to onboard new person with 'user_id' user id
      final auuid = Uuid().v4();
      final personnel = PersonnelBuilder.create(
        auuid: auuid,
        userId: "existing",
        ouuid: operation.uuid,
      );
      await harness.personnelBloc.create(personnel);
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelCreated>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.affiliationBloc.persons.length, 2, reason: "SHOULD contain 2 persons");
      expect(harness.affiliationBloc.repo.length, 2, reason: "SHOULD contain 2 affiliations");
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain 2 personnels");

      expect(
        harness.affiliationBloc.persons.find(where: (p) => p.userId == existing.userId).firstOrNull,
        equals(existing),
        reason: "SHOULD be equal",
      );
      expect(
        harness.affiliationBloc.repo.find(where: (a) => a.person.userId == existing.userId).firstOrNull?.person,
        equals(existing),
        reason: "SHOULD be equal",
      );
      expect(
        harness.personnelBloc.repo.find(where: (p) => p.person.userId == existing.userId).firstOrNull?.person,
        equals(existing),
        reason: "SHOULD be equal",
      );
    });

    test('SHOULD replace affiliation on conflict', () async {
      // Arrange - person in backend only
      final operation = await _prepare(harness, offline: false);
      await harness.affiliationBloc.load();
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain 1 personnel");
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 person");
      expect(harness.affiliationBloc.repo.length, 1, reason: "SHOULD contain 1 affiliation");
      final existing = harness.affiliationBloc.repo.values.first;

      // Act - attempt to add another affiliation
      final duplicate = existing.copyWith(uuid: Uuid().v4());
      final auuid = Uuid().v4();
      final personnel = PersonnelBuilder.create(
        auuid: auuid,
        ouuid: operation.uuid,
      );
      await harness.personnelBloc.create(personnel.copyWith(
        affiliation: duplicate,
      ));
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelCreated>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain 2 personnel");
      expect(harness.affiliationBloc.persons.length, 1, reason: "SHOULD contain 1 persons");
      expect(harness.affiliationBloc.repo.length, 1, reason: "SHOULD contain 2 affiliations");
      expect(
        harness.affiliationBloc.repo[existing.uuid],
        equals(existing),
        reason: "SHOULD contain existing affiliation",
      );
      expect(
        harness.affiliationBloc.repo.containsKey(duplicate.uuid),
        isFalse,
        reason: "SHOULD not contain duplicate affiliation",
      );
      expect(
        harness.personnelBloc.repo[personnel.uuid].affiliation,
        equals(existing),
        reason: "SHOULD contain existing affiliation",
      );
    });

    test('SHOULD delete personnel and push to backend', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = await harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.delete(personnel.uuid);

      // Assert
      await expectStorageStatusLater(
        personnel.uuid,
        harness.personnelBloc.repo,
        StorageStatus.deleted,
        remote: true,
      );
      verify(harness.personnelService.delete(any)).called(1);
      expect(
        harness.personnelBloc.repo.states[personnel.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = await harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be local',
          isTrue,
        )),
      );
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsUnloaded>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
    });

    test('SHOULD NOT be empty after reload', () async {
      // Arrange
      final operation = await _prepare(harness, offline: false);
      final person = await harness.personService.add();
      final affiliation = await harness.affiliationService.add(puuid: person.uuid);
      final personnel = harness.personnelService.add(operation.uuid, auuid: affiliation.uuid);
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.load();
      await expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      // Assert
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expect(
        harness.personnelBloc.repo.containsKey(personnel.uuid),
        isTrue,
        reason: "SHOULD contain personnel ${personnel.uuid}",
      );
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
      final operation = await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create(ouuid: operation.uuid);

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
      final operation = await _prepare(harness, offline: true);
      final personnel1 = PersonnelBuilder.create(ouuid: operation.uuid, status: PersonnelStatus.alerted);
      final personnel2 = PersonnelBuilder.create(ouuid: operation.uuid, status: PersonnelStatus.alerted);
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
      final operation = await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
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
      final operation = await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.unload();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.personnelBloc, isA<PersonnelsUnloaded>());
    });

    test('SHOULD NOT be empty after reload', () async {
      // Arrange
      final operation = await _prepare(harness, offline: true);
      final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

      // Act
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsLoaded>()]);
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
  final operation = await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");
  expect(harness.personnelBloc.ouuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.operationsBloc.unload();

  // Assert
  await expectThroughLater(
    harness.personnelBloc.stream,
    emits(isA<PersonnelsUnloaded>()),
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
  final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(status: OperationStatus.completed),
  );

  // Assert
  await expectThroughLater(
    harness.personnelBloc.stream,
    emits(isA<PersonnelsUnloaded>()),
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
  final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
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
    harness.personnelBloc.stream,
    emits(isA<PersonnelsUnloaded>()),
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
  final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnels");

  // Act
  await harness.operationsBloc.delete(operation.uuid);

  // Assert
  await expectThroughLater(
    harness.personnelBloc.stream,
    emits(isA<PersonnelsUnloaded>()),
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
    harness.personnelBloc.stream,
    emitsThrough(isA<UserMobilized>()),
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
  final personnels = harness.personnelBloc.findUser(userId: harness.userId);
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
  final operation = await _prepare(harness, offline: offline);
  final personnel = PersonnelBuilder.create(ouuid: operation.uuid);
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
    [
      isA<PersonnelsUnloaded>(),
      isA<PersonnelsLoaded>(),
    ],
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
Future<Operation> _prepare(
  BlocTestHarness harness, {
  @required bool offline,
  bool create = true,
}) async {
  await harness.userBloc.login(
    username: harness.username,
    password: harness.password,
  );

  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }

  // Wait for user to complete onboarding
  await expectThroughLater(
    harness.affiliationBloc.stream,
    emits(isA<UserOnboarded>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );

  // A user must be authenticated
  expect(
    harness.userBloc.isAuthenticated,
    isTrue,
    reason: "SHOULD be authenticated",
  );

  if (!create) {
    return Future.value();
  }

  // Create operation
  final incident = IncidentBuilder.create();
  final operation = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Await events
  await Future.wait([
    expectThroughLater(
        harness.operationsBloc.stream,
        emits(isA<OperationSelected>().having(
          (event) {
            return event.isLocal;
          },
          'Should always be local',
          isTrue,
        ))),
    expectThroughLater(
        harness.personnelBloc.stream,
        emits(isA<PersonnelsLoaded>().having(
          (event) {
            return event.isRemote;
          },
          'Should be ${offline ? 'local' : 'remote'}',
          !offline,
        ))),
    expectThroughLater(
      harness.personnelBloc.stream,
      emits(isA<UserMobilized>().having(
        (event) {
          return event.isRemote;
        },
        'Should be ${offline ? 'local' : 'remote'}',
        !offline,
      )),
    )
  ]);

  // Assert personnel states
  expect(
    harness.operationsBloc.isUnselected,
    isFalse,
    reason: "SHOULD NOT be unset",
  );
  expect(
    harness.personnelBloc.ouuid,
    operation.uuid,
    reason: "SHOULD depend on operation ${operation.uuid}",
  );

  // Assert only user exists as personnel
  expect(
    harness.personnelBloc.findUser(userId: harness.userBloc.userId),
    isNotEmpty,
    reason: "User SHOULD BE mobilized",
  );
  expect(
    harness.personnelBloc.repo.length,
    equals(1),
    reason: "Only user SHOULD BE mobilized",
  );
  expect(
    harness.affiliationBloc.findUserAffiliation(userId: harness.userBloc.userId),
    isNotNull,
    reason: "User SHOULD HAVE affiliation",
  );
  expect(
    harness.affiliationBloc.repo.length,
    equals(1),
    reason: "Only user SHOULD BE affiliated",
  );
  expect(
    harness.affiliationBloc.persons.findUser(harness.userBloc.userId),
    isNotNull,
    reason: "User SHOULD BE a person",
  );
  expect(
    harness.affiliationBloc.persons.length,
    equals(1),
    reason: "Only user SHOULD BE a person",
  );

  return operation;
}
