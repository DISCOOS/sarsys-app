import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

const UNTRUSTED = 'username';
const PASSWORD = 'password';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc(authenticated: false)
    ..install();

  test(
    'Operation bloc should be EMPTY and UNSET',
    () async {
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
      expect(harness.operationsBloc.repo.isEmpty, isTrue, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.initialState, isA<OperationsEmpty>(), reason: "Unexpected operation state");
      expect(harness.operationsBloc, emits(isA<OperationsEmpty>()));
    },
  );

  test(
    'Operation bloc should be load when user is authenticated',
    () async {
      // Arrange
      await _authenticate(harness);

      // Assert
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
      expect(harness.operationsBloc.initialState, isA<OperationsEmpty>(), reason: "Unexpected operation state");
    },
  );

  test(
    'Operation bloc should be unload when user is logged out',
    () async {
      // Arrange
      await _authenticate(harness);
      await expectThroughLater(harness.operationsBloc, emits(isA<OperationLoaded>()), close: false);

      // Act
      await harness.userBloc.logout();

      // Assert
      await expectThroughLater(harness.operationsBloc, emits(isA<OperationUnloaded>()));
    },
  );

  test(
    'Operation bloc should be reload when user is logged in again',
    () async {
      // Arrange
      await _authenticate(harness);
      await harness.userBloc.logout();
      await expectThroughLater(harness.operationsBloc, emits(isA<OperationUnloaded>()), close: false);

      // Act
      await _authenticate(harness);

      // Assert
      await expectThroughLater(harness.operationsBloc, emits(isA<OperationLoaded>()));
    },
  );

  group('WHEN OperationBloc is ONLINE', () {
    test('SHOULD load operations', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);

      // Act
      List<Operation> operations = await harness.operationsBloc.load();

      // Assert
      expect(operations.length, 2, reason: "SHOULD contain two operations");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD NOT be in SELECTED state");
      await expectThroughLater(
        harness.operationsBloc,
        emits(isA<OperationLoaded>()),
        close: false,
      );
    });

    test('SHOULD selected first operation', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);
      List<Operation> operations = await harness.operationsBloc.load();

      // Act
      await harness.operationsBloc.select(operations.first.uuid);

      // Assert
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operations.first.uuid), reason: "SHOULD select first");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationLoaded>(), isA<OperationSelected>()]);
    });

    test('SHOULD selected last operation', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);
      List<Operation> operations = await harness.operationsBloc.load();

      // Act
      await harness.operationsBloc.select(operations.last.uuid);

      // Assert
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operations.last.uuid), reason: "SHOULD select last");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationLoaded>(), isA<OperationSelected>()]);
    });

    test('SHOULD create operation and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.load();

      // Act
      await harness.operationsBloc.create(operation, incident: incident);

      // Assert
      verify(harness.operationService.create(any)).called(1);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation.uuid), reason: "SHOULD select created");
      expect(harness.operationsBloc.selected.incident.uuid, equals(incident.uuid), reason: "SHOULD reference incident");
      expect(
        harness.operationsBloc.incidents.containsKey(operation.incident.uuid),
        isTrue,
        reason: "SHOULD contain incident",
      );
      expectThroughInOrder(harness.operationsBloc, [isA<OperationCreated>(), isA<OperationSelected>()]);
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");

      // Act
      final changed = await harness.operationsBloc.update(operation.copyWith(name: "Changed"));

      // Assert
      verify(harness.operationService.update(any)).called(1);
      expect(changed.name, "Changed", reason: "SHOULD changed name");
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUpdated>(), isA<OperationSelected>()]);
    });

    test('SHOULD delete operation and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.delete(operation.uuid);

      // Assert
      verify(harness.operationService.delete(any)).called(1);
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnselected>(), isA<OperationDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.unload();

      // Assert
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnselected>(), isA<OperationUnloaded>()]);
    });

    test('SHOULD reload one operation after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.unload();
      await harness.operationsBloc.load();

      // Assert
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnloaded>(), isA<OperationLoaded>()]);
    });
  });

  group('WHEN OperationBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);

      // Act
      List<Operation> operations = await harness.operationsBloc.load();

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(operations.length, 0, reason: "SHOULD NOT contain operations");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD NOT be in SELECTED state");
      await expectThroughLater(
        harness.operationsBloc,
        emits(isA<OperationLoaded>()),
      );
    });

    test('SHOULD selected first operation with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();

      final incident1 = IncidentBuilder.create();
      final incident2 = IncidentBuilder.create();
      final operation1 = OperationBuilder.create(harness.userBloc.userId, iuuid: incident1.uuid);
      final operation2 = OperationBuilder.create(harness.userBloc.userId, iuuid: incident2.uuid);
      await harness.operationsBloc.create(operation1, incident: incident1, selected: false);
      await harness.operationsBloc.create(operation2, incident: incident2, selected: false);

      // Act
      await harness.operationsBloc.select(operation1.uuid);

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(
        harness.operationsBloc.repo.states[operation1.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation1.uuid), reason: "SHOULD selected first");
      expect(harness.operationsBloc, emitsThrough(isA<OperationSelected>()));
    });

    test('SHOULD selected last operation with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident1 = IncidentBuilder.create();
      final incident2 = IncidentBuilder.create();
      final operation1 = OperationBuilder.create(harness.userBloc.userId, iuuid: incident1.uuid);
      final operation2 = OperationBuilder.create(harness.userBloc.userId, iuuid: incident2.uuid);
      await harness.operationsBloc.create(operation1, incident: incident1, selected: false);
      await harness.operationsBloc.create(operation2, incident: incident2, selected: false);

      // Act
      await harness.operationsBloc.select(operation2.uuid);

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(
        harness.operationsBloc.repo.states[operation2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation2.uuid), reason: "SHOULD selected last");
      expect(harness.operationsBloc, emitsThrough(isA<OperationSelected>()));
    });

    test('SHOULD create operation with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);

      // Act
      await harness.operationsBloc.create(operation, incident: incident);

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(
        harness.operationsBloc.repo.states[operation.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation.uuid), reason: "SHOULD select created");
      expect(harness.operationsBloc.selected.incident.uuid, equals(incident.uuid), reason: "SHOULD reference incident");
      expect(
        harness.operationsBloc.incidents.containsKey(operation.incident.uuid),
        isTrue,
        reason: "SHOULD contain incident",
      );
      expectThroughInOrder(harness.operationsBloc, [isA<OperationCreated>(), isA<OperationSelected>()]);
    });

    test('SHOULD update operation with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.create(operation, incident: incident, selected: false);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");

      // Act
      await harness.operationsBloc.update(operation);

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(
        harness.operationsBloc.repo.states[operation.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation.uuid), reason: "SHOULD select created");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUpdated>(), isA<OperationSelected>()]);
    });

    test('SHOULD delete local operation', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.create(operation, incident: incident);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.delete(operation.uuid);

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnselected>(), isA<OperationDeleted>()]);
    });

    test('SHOULD BE empty and UNSET after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.create(operation, incident: incident);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.unload();

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnselected>(), isA<OperationUnloaded>()]);
    });

    test('SHOULD reload local values after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.create(operation, incident: incident);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");
      await harness.operationsBloc.unload();

      // Act
      await harness.operationsBloc.load();

      // Assert
      verifyNoMoreInteractions(harness.operationService);
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc, emits(isA<OperationUnloaded>()));
    });
  });
}

// Authenticate user
// Since 'authenticate = false' is passed
// to Harness to allow for testing of
// initial states and transitions of
// OperationBloc, all tests that require
// an authenticated user must call this
Future _authenticate(BlocTestHarness harness, {bool reset = true}) async {
  await harness.userBloc.login(username: UNTRUSTED, password: PASSWORD);
  // Wait for UserAuthenticated event
  // Wait until operations are loaded
  await expectThroughLater(
    harness.operationsBloc,
    emits(isA<OperationLoaded>()),
    close: false,
  );
  if (reset) {
    clearInteractions(harness.operationService);
  }
}
