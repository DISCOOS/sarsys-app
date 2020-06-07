import 'package:SarSys/features/incident/presentation/blocs/incident_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

const UNTRUSTED = 'username';
const PASSWORD = 'password';

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc(authenticated: false)
    ..install();

  test(
    'Incident bloc should be EMPTY and UNSET',
    () async {
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
      expect(harness.incidentBloc.repo.isEmpty, isTrue, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.initialState, isA<IncidentsEmpty>(), reason: "Unexpected incident state");
      expect(harness.incidentBloc, emits(isA<IncidentsEmpty>()));
    },
  );

  test(
    'Incident bloc should be load when user is authenticated',
    () async {
      // Arrange
      await _authenticate(harness);

      // Assert
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
      expect(harness.incidentBloc.initialState, isA<IncidentsEmpty>(), reason: "Unexpected incident state");
    },
  );

  test(
    'Incident bloc should be unload when user is logged out',
    () async {
      // Arrange
      await _authenticate(harness);
      await expectThroughLater(harness.incidentBloc, emits(isA<IncidentsLoaded>()), close: false);

      // Act
      await harness.userBloc.logout();

      // Assert
      await expectThroughLater(harness.incidentBloc, emits(isA<IncidentsUnloaded>()));
    },
  );

  test(
    'Incident bloc should be reload when user is logged in again',
    () async {
      // Arrange
      await _authenticate(harness);
      await harness.userBloc.logout();
      await expectThroughLater(harness.incidentBloc, emits(isA<IncidentsUnloaded>()), close: false);

      // Act
      await _authenticate(harness);

      // Assert
      await expectThroughLater(harness.incidentBloc, emits(isA<IncidentsLoaded>()));
    },
  );

  group('WHEN IncidentBloc is ONLINE', () {
    test('SHOULD load incidents', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);

      // Act
      List<Incident> incidents = await harness.incidentBloc.load();

      // Assert
      expect(incidents.length, 2, reason: "SHOULD contain two incidents");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD NOT be in SELECTED state");
      await expectThroughLater(
        harness.incidentBloc,
        emits(isA<IncidentsLoaded>()),
        close: false,
      );
    });

    test('SHOULD selected first incident', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);
      List<Incident> incidents = await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.select(incidents.first.uuid);

      // Assert
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incidents.first.uuid), reason: "SHOULD select first");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsLoaded>(), isA<IncidentSelected>()]);
    });

    test('SHOULD selected last incident', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);
      List<Incident> incidents = await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.select(incidents.last.uuid);

      // Assert
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incidents.last.uuid), reason: "SHOULD select last");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsLoaded>(), isA<IncidentSelected>()]);
    });

    test('SHOULD create incident and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.create(incident);

      // Assert
      verify(harness.incidentService.create(any)).called(1);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentCreated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD update incident and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");

      // Act
      final changed = await harness.incidentBloc.update(incident.cloneWith(name: "Changed"));

      // Assert
      verify(harness.incidentService.update(any)).called(1);
      expect(changed.name, "Changed", reason: "SHOULD changed name");
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUpdated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD delete incident and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      await harness.incidentBloc.select(incident.uuid);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.delete(incident.uuid);

      // Assert
      verify(harness.incidentService.delete(any)).called(1);
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnselected>(), isA<IncidentDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      await harness.incidentBloc.select(incident.uuid);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.unload();

      // Assert
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnselected>(), isA<IncidentsUnloaded>()]);
    });

    test('SHOULD reload one incident after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      await harness.incidentBloc.select(incident.uuid);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.unload();
      await harness.incidentBloc.load();

      // Assert
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsUnloaded>(), isA<IncidentsLoaded>()]);
    });
  });

  group('WHEN IncidentBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);

      // Act
      List<Incident> incidents = await harness.incidentBloc.load();

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(incidents.length, 0, reason: "SHOULD NOT contain incidents");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD NOT be in SELECTED state");
      await expectThroughLater(
        harness.incidentBloc,
        emits(isA<IncidentsLoaded>()),
      );
    });

    test('SHOULD selected first incident with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident1 = IncidentBuilder.create(harness.userBloc.userId);
      final incident2 = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident1, selected: false);
      await harness.incidentBloc.create(incident2, selected: false);

      // Act
      await harness.incidentBloc.select(incident1.uuid);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(
        harness.incidentBloc.repo.states[incident1.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident1.uuid), reason: "SHOULD selected first");
      expect(harness.incidentBloc, emitsThrough(isA<IncidentSelected>()));
    });

    test('SHOULD selected last incident with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident1 = IncidentBuilder.create(harness.userBloc.userId);
      final incident2 = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident1, selected: false);
      await harness.incidentBloc.create(incident2, selected: false);

      // Act
      await harness.incidentBloc.select(incident2.uuid);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(
        harness.incidentBloc.repo.states[incident2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident2.uuid), reason: "SHOULD selected last");
      expect(harness.incidentBloc, emitsThrough(isA<IncidentSelected>()));
    });

    test('SHOULD create incident with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);

      // Act
      await harness.incidentBloc.create(incident);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(
        harness.incidentBloc.repo.states[incident.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentCreated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD update incident with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident, selected: false);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");

      // Act
      await harness.incidentBloc.update(incident);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(
        harness.incidentBloc.repo.states[incident.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUpdated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD delete local incident', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.delete(incident.uuid);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnselected>(), isA<IncidentDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.unload();

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnselected>(), isA<IncidentsUnloaded>()]);
    });

    test('SHOULD reload local values after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");
      await harness.incidentBloc.unload();

      // Act
      await harness.incidentBloc.load();

      // Assert
      verifyNoMoreInteractions(harness.incidentService);
      expect(harness.incidentBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc, emits(isA<IncidentsUnloaded>()));
    });
  });
}

// Authenticate user
// Since 'authenticate = false' is passed
// to Harness to allow for testing of
// initial states and transitions of
// IncidentBloc, all tests that require
// an authenticated user must call this
Future _authenticate(BlocTestHarness harness, {bool reset = true}) async {
  await harness.userBloc.login(username: UNTRUSTED, password: PASSWORD);
  // Wait for UserAuthenticated event
  // Wait until incidents are loaded
  await expectThroughLater(
    harness.incidentBloc,
    emits(isA<IncidentsLoaded>()),
    close: false,
  );
  if (reset) {
    clearInteractions(harness.incidentService);
  }
}
