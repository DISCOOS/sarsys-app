import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/mock/personnels.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc()
    ..withPersonnelBloc()
    ..install();

  test(
    'Personnel bloc should be EMPTY and UNSET',
    () async {
      expect(harness.personnelBloc.iuuid, isNull, reason: "SHOULD BE unset");
      expect(harness.personnelBloc.personnels.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.initialState, isA<PersonnelsEmpty>(), reason: "Unexpected personnel state");
      await expectExactlyLater(harness.personnelBloc, [isA<PersonnelsEmpty>()]);
    },
  );

  group('WHEN personnelBloc is ONLINE', () {
    test('SHOULD load personnel', () async {
      // Arrange
      harness.connectivity.cellular();
      Incident incident = await _prepare(harness);
      final personnel1 = harness.personnelService.add(incident.uuid);
      final personnel2 = harness.personnelService.add(incident.uuid);

      // Act
      List<Personnel> personnel = await harness.personnelBloc.load();

      // Assert
      expect(personnel.length, 2, reason: "SHOULD contain two personnel");
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
      expectThrough(harness.personnelBloc, emits(isA<PersonnelsLoaded>()));
    });

    test('SHOULD create personnel and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final personnel = PersonnelBuilder.create();

      // Act
      await harness.personnelBloc.create(personnel);

      // Assert
      verify(harness.personnelService.create(any, any)).called(1);
      expectStorageStatus(
        harness.personnelBloc.repo.states[personnel.uuid],
        StorageStatus.created,
        remote: true,
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update incident and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final personnel = harness.personnelService.add(incident.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.update(personnel.cloneWith(status: PersonnelStatus.OnScene));

      // Assert
      verify(harness.personnelService.update(any)).called(1);
      expectStorageStatus(
        harness.personnelBloc.repo.states[personnel.uuid],
        StorageStatus.updated,
        remote: true,
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    test('SHOULD delete personnel and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final personnel = harness.personnelService.add(incident.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.delete(personnel);

      // Assert
      verify(harness.personnelService.delete(any)).called(1);
      expect(
        harness.personnelBloc.repo.states[personnel.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT BE unset");
      expect(harness.personnelBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      harness.personnelService.add(incident.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.unload();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expectThrough(harness.personnelBloc, isA<PersonnelsUnloaded>());
    });

    test('SHOULD reload one personnel after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      final personnel = harness.personnelService.add(incident.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.unload();
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()]);
    });

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
    });
  });

  group('WHEN personnelBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      harness.personnelService.add(harness.userBloc.userId);
      harness.personnelService.add(harness.userBloc.userId);

      // Act
      List<Personnel> personnel = await harness.personnelBloc.load();

      // Assert
      expect(personnel.length, 0, reason: "SHOULD NOT contain personnel");
      expect(harness.personnelBloc, emits(isA<PersonnelsLoaded>()));
    });

    test('SHOULD create personnel with state CREATED', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();

      // Act
      await harness.personnelBloc.create(personnel);

      // Assert
      expect(
        harness.personnelBloc.repo.states[personnel.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update personnel with state CREATED', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel1 = PersonnelBuilder.create(status: PersonnelStatus.Mobilized);
      final personnel2 = PersonnelBuilder.create(status: PersonnelStatus.Mobilized);
      await harness.personnelBloc.create(personnel1);
      await harness.personnelBloc.create(personnel2);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnel");

      // Act
      await harness.personnelBloc.update(personnel2.cloneWith(status: PersonnelStatus.OnScene));

      // Assert
      expect(
        harness.personnelBloc.repo.states[personnel2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(
        harness.personnelBloc.repo[personnel1.uuid].status,
        equals(PersonnelStatus.Mobilized),
        reason: "SHOULD be status Mobilized",
      );
      expect(
        harness.personnelBloc.repo[personnel2.uuid].status,
        equals(PersonnelStatus.OnScene),
        reason: "SHOULD be status OnScene",
      );
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    test('SHOULD delete local personnel', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.delete(personnel);

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.unload();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.personnelBloc, isA<PersonnelsUnloaded>());
    });

    test('SHOULD be empty after reload', () async {
      // Arrange
      harness.connectivity.offline();
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.unload();
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()]);
    });

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
    });
  });
}

Future _testShouldUnloadWhenIncidentIsUnloaded(BlocTestHarness harness) async {
  await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
  expect(harness.personnelBloc.iuuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.incidentBloc.unload();

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsResolved(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Resolved),
  );

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsCancelled(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Cancelled),
  );

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsDeleted(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

  // Act
  await harness.incidentBloc.delete(incident.uuid);

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  expect(harness.personnelBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

Future _testShouldReloadWhenIncidentIsSwitched(BlocTestHarness harness) async {
  await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

  // Act
  var incident2 = IncidentBuilder.create(harness.userBloc.userId);
  incident2 = await harness.incidentBloc.create(incident2, selected: true);

  // Assert
  await expectThroughInOrderLater(
    harness.personnelBloc,
    [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()],
  );
  expect(harness.personnelBloc.iuuid, incident2.uuid, reason: "SHOULD change to ${incident2.uuid}");
  expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.personnelBloc.repo.containsKey(personnel.uuid),
    isFalse,
    reason: "SHOULD NOT contain personnel ${personnel.uuid}",
  );
}

/// Prepare blocs for testing
Future<Incident> _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

  // Create incident
  var incident = IncidentBuilder.create(harness.userBloc.userId);
  incident = await harness.incidentBloc.create(incident);

  // Prepare IncidentBloc
  await expectThroughLater(harness.incidentBloc, emits(isA<IncidentSelected>()), close: false);
  expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelsLoaded>()), close: false);
  expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.personnelBloc.iuuid, incident.uuid, reason: "SHOULD depend on incident ${incident.uuid}");

  return incident;
}
