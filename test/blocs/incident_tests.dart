import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc()
    ..install();
//  final unauthorized = UserServiceMock.createToken(
//    "unauthorized",
//    UserRole.commander,
//  ).toUser();

  test(
    'Incident bloc should be EMPTY and UNSET',
    () async {
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expect(harness.incidentBloc.initialState, isA<IncidentUnset>(), reason: "Unexpected incident state");
      await expectExactlyLater(harness.incidentBloc, [isA<IncidentUnset>()]);
    },
  );

  group('WHEN IncidentBloc is ONLINE', () {
    test('SHOULD load two incidents', () async {
      // Arrange
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);

      // Act
      List<Incident> incidents = await harness.incidentBloc.load();

      // Assert
      expect(incidents.length, 2, reason: "SHOULD contain two incidents");
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD NOT be in SELECTED state");
      expect(harness.incidentBloc, emits(isA<IncidentsLoaded>()));
    });

    test('SHOULD selected first incident', () async {
      // Arrange
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);
      List<Incident> incidents = await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.select(incidents.first.uuid);

      // Assert
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incidents.first.uuid), reason: "SHOULD select first");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsLoaded>(), isA<IncidentSelected>()]);
    });

    test('SHOULD selected last incident', () async {
      // Arrange
      harness.connectivity.cellular();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);
      List<Incident> incidents = await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.select(incidents.last.uuid);

      // Assert
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incidents.last.uuid), reason: "SHOULD select last");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsLoaded>(), isA<IncidentSelected>()]);
    });

    test('SHOULD create incident and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.load();

      // Act
      await harness.incidentBloc.create(incident);

      // Assert
      verify(harness.incidentService.create(any)).called(1);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentCreated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD update incident and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");

      // Act
      await harness.incidentBloc.update(incident);

      // Assert
      verify(harness.incidentService.update(any)).called(1);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUpdated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD delete incident and push to backend', () async {
      // Arrange
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
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnset>(), isA<IncidentDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after clear', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      await harness.incidentBloc.select(incident.uuid);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.clear();

      // Assert
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnset>(), isA<IncidentsCleared>()]);
    });

    test('SHOULD reload one incident after clear', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = harness.incidentService.add(harness.userBloc.userId);
      await harness.incidentBloc.load();
      await harness.incidentBloc.select(incident.uuid);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.clear();
      await harness.incidentBloc.load();

      // Assert
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentsCleared>(), isA<IncidentsLoaded>()]);
    });
  });

  group('WHEN IncidentBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      harness.connectivity.offline();
      harness.incidentService.add(harness.userBloc.userId);
      harness.incidentService.add(harness.userBloc.userId);

      // Act
      List<Incident> incidents = await harness.incidentBloc.load();

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(incidents.length, 0, reason: "SHOULD NOT contain incidents");
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD NOT be in SELECTED state");
      expect(harness.incidentBloc, emits(isA<IncidentsLoaded>()));
    });

    test('SHOULD selected first incident with state CREATED', () async {
      // Arrange
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
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident1.uuid), reason: "SHOULD selected first");
      expect(harness.incidentBloc, emitsThrough(isA<IncidentSelected>()));
    });

    test('SHOULD selected last incident with state CREATED', () async {
      // Arrange
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
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident2.uuid), reason: "SHOULD selected last");
      expect(harness.incidentBloc, emitsThrough(isA<IncidentSelected>()));
    });

    test('SHOULD create incident with state CREATED', () async {
      // Arrange
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
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentCreated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD update incident and push to backend', () async {
      // Arrange
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident, selected: false);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");

      // Act
      await harness.incidentBloc.update(incident);

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.isUnset, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.incidentBloc.selected.uuid, equals(incident.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUpdated>(), isA<IncidentSelected>()]);
    });

    test('SHOULD delete incident and push to backend', () async {
      // Arrange
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
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnset>(), isA<IncidentDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after clear', () async {
      // Arrange
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.incidentBloc.clear();

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.incidentBloc, [isA<IncidentUnset>(), isA<IncidentsCleared>()]);
    });

    test('SHOULD reload as EMPTY after clear', () async {
      // Arrange
      harness.connectivity.offline();
      final incident = IncidentBuilder.create(harness.userBloc.userId);
      await harness.incidentBloc.create(incident);
      expect(harness.incidentBloc.repo.length, 1, reason: "SHOULD contain one incident");
      expect(harness.incidentBloc.selected?.uuid, incident.uuid, reason: "SHOULD BE selected");
      await harness.incidentBloc.clear();

      // Act
      await harness.incidentBloc.load();

      // Assert
      verifyZeroInteractions(harness.incidentService);
      expect(harness.incidentBloc.isUnset, isTrue, reason: "SHOULD be unset");
      expect(harness.incidentBloc.repo.length, 0, reason: "SHOULD contain no incidents");
      expect(harness.incidentBloc, emits(isA<IncidentsCleared>()));
    });
  });
}
