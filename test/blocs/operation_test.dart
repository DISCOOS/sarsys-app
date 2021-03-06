import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

import '../mock/incident_service_mock.dart';
import '../mock/operation_service_mock.dart';

import 'harness.dart';

const UNTRUSTED = 'username';
const PASSWORD = 'password';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc(
      username: UNTRUSTED,
      password: PASSWORD,
      authenticated: false,
    )
    ..install();

  test('Operation bloc should be EMPTY and UNSET', () async {
    expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
    expect(harness.operationsBloc.repo.isEmpty, isTrue, reason: "SHOULD BE empty");
    expect(harness.operationsBloc.state, isA<OperationsEmpty>());
  });

  test('Operation bloc should be load when user is authenticated', () async {
    // Arrange
    await _authenticate(harness);

    // Assert
    expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD BE unset");
  });

  test('Operation bloc should be unload when user is logged out', () async {
    // Arrange
    await _authenticate(harness);

    // Act
    await _logout(harness);

    // Assert
    expect(harness.operationsBloc.state, isA<OperationsUnloaded>());
  });

  test(
    'Operation bloc should be reload when user is logged in again',
    () async {
      // Arrange
      await _authenticate(harness);

      // Act
      await _logout(harness);
      await _authenticate(
        harness,
        exists: true,
      );

      // Assert
      expect(harness.operationsBloc.state, isA<OperationsLoaded>());
    },
  );

  group('WHEN OperationBloc is ONLINE', () {
    test('SHOULD load operations', () async {
      // Arrange
      await _authenticate(harness);
      final iuuid = Uuid().v4();
      harness.connectivity.cellular();
      final localOperations = await harness.operationsBloc.load();
      final localIncidents = harness.operationsBloc.incidents.values;

      // Act
      harness.incidentService.add(uuid: iuuid);
      harness.operationService.add(harness.userBloc.userId, iuuid: iuuid);
      harness.operationService.add(harness.userBloc.userId, iuuid: iuuid);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);

      // Assert
      final remoteOperations = harness.operationsBloc.values;
      final remoteIncidents = harness.operationsBloc.incidents.values;
      expect(localIncidents.length, 0, reason: "SHOULD contain zero incidents");
      expect(localOperations.length, 0, reason: "SHOULD contain zero operations");
      expect(remoteIncidents.length, 1, reason: "SHOULD contain one incident");
      expect(remoteOperations.length, 2, reason: "SHOULD contain two operations");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD NOT be in SELECTED state");
    });

    test('SHOULD selected first operation', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);
      final operations = harness.operationsBloc.repo.values;

      // Act
      await harness.operationsBloc.select(operations.first.uuid);

      // Assert
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operations.first.uuid), reason: "SHOULD select first");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationSelected>()]);
    });

    test('SHOULD selected last operation', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      harness.operationService.add(harness.userBloc.userId);
      harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);
      final operations = harness.operationsBloc.repo.values;

      // Act
      await harness.operationsBloc.select(operations.last.uuid);

      // Assert
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operations.last.uuid), reason: "SHOULD select last");
      expectThroughInOrder(harness.operationsBloc, [isA<OperationSelected>()]);
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
      await expectRemoteIsNotEmpty<OperationCreated>(harness);

      // Assert local state
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
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final incident = harness.incidentService.add();
      final operation = harness.operationService.add(harness.userBloc.userId, iuuid: incident.uuid);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);
      final operations = harness.operationsBloc.repo.values;
      expect(operations.length, 1, reason: "SHOULD contain one operation");

      // Act
      final changed = await harness.operationsBloc.update(operation.copyWith(name: "Changed"));
      await expectRemoteIsNotEmpty<OperationUpdated>(harness);

      // Assert
      verify(harness.operationService.update(any)).called(1);
      expect(changed.name, "Changed", reason: "SHOULD changed name");
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation.uuid), reason: "SHOULD select created");
    });

    test('SHOULD delete operation and push to backend', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);

      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.delete(operation.uuid);
      await expectRemoteIsNotEmpty<OperationDeleted>(harness);

      // Assert
      verify(harness.operationService.delete(any)).called(1);
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
    });

    test('SHOULD BE empty and UNSET after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);
      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.unload();
      await expectLocalIsNotEmpty<OperationsUnloaded>(harness);

      // Assert
      expect(harness.operationsBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.selected?.uuid, isNull, reason: "SHOULD BE unset");
    });

    test('SHOULD reload one operation after unload', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.cellular();
      final operation = harness.operationService.add(harness.userBloc.userId);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);
      await harness.operationsBloc.select(operation.uuid);
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
      expect(harness.operationsBloc.selected?.uuid, operation.uuid, reason: "SHOULD BE selected");

      // Act
      await harness.operationsBloc.unload();
      await expectLocalIsNotEmpty<OperationsUnloaded>(harness);
      await harness.operationsBloc.load();
      await expectRemoteIsNotEmpty<OperationsLoaded>(harness);

      // Assert
      expect(harness.operationsBloc.isUnselected, isTrue, reason: "SHOULD be unset");
      expect(harness.operationsBloc.repo.length, 1, reason: "SHOULD contain one operation");
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
        harness.operationsBloc.stream,
        emits(isA<OperationsLoaded>()),
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
      expectThroughLater(
        harness.operationsBloc.stream,
        emits(isA<OperationSelected>().having((e) => e.isLocal, 'Should be local', isTrue)),
      );

      // Assert
      verifyZeroInteractions(harness.operationService);
      expect(
        harness.operationsBloc.repo.states[operation2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.operationsBloc.isUnselected, isFalse, reason: "SHOULD be in SELECTED state");
      expect(harness.operationsBloc.selected.uuid, equals(operation2.uuid), reason: "SHOULD selected last");
    });

    test('SHOULD create operation with state CREATED', () async {
      // Arrange
      await _authenticate(harness);
      harness.connectivity.offline();
      final incident = IncidentBuilder.create();
      final operation = OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid);

      // Act
      await harness.operationsBloc.create(operation, incident: incident);
      expectThroughLater(
        harness.operationsBloc.stream,
        emits(isA<OperationSelected>().having((e) => e.isLocal, 'Should be local', isTrue)),
      );

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
      expectThroughLater(
        harness.operationsBloc.stream,
        emits(isA<OperationSelected>().having((e) => e.isLocal, 'Should be local', isTrue)),
      );

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
      expectThroughInOrder(harness.operationsBloc, [isA<OperationUnselected>(), isA<OperationsUnloaded>()]);
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
    });
  });
}

Future<void> _logout(BlocTestHarness harness) async {
  await harness.userBloc.logout();
  await Future.wait([
    expectThroughLater(
      harness.operationsBloc.stream,
      isA<OperationsUnloaded>(),
    ),
    expectThroughLater(
      harness.affiliationBloc.stream,
      isA<AffiliationsUnloaded>(),
    )
  ]);
}

Future<void> expectLocalIsEmpty<T extends OperationState>(BlocTestHarness harness) {
  return expectThroughLater(
    harness.operationsBloc.stream,
    emits(isA<T>().having(
      (event) {
        return event.isLocal && (event.data is Iterable ? (event.data as Iterable).isEmpty : event.data == null);
      },
      'Should be remote and not empty',
      isTrue,
    )),
  );
}

Future<void> expectLocalIsNotEmpty<T extends OperationState>(BlocTestHarness harness) {
  return expectThroughLater(
    harness.operationsBloc.stream,
    emits(isA<T>().having(
      (event) {
        return event.isLocal && (event.data is Iterable ? (event.data as Iterable).isNotEmpty : event.data != null);
      },
      'Should be remote and not empty',
      isTrue,
    )),
  );
}

Future<void> expectRemoteIsEmpty<T extends OperationState>(BlocTestHarness harness) {
  return expectThroughLater(
    harness.operationsBloc.stream,
    emits(isA<T>().having(
      (event) {
        return event.isRemote && (event.data is Iterable ? (event.data as Iterable).isEmpty : event.data == null);
      },
      'Should be remote and not empty',
      isTrue,
    )),
  );
}

Future<void> expectRemoteIsNotEmpty<T extends OperationState>(BlocTestHarness harness) {
  return expectThroughLater(
    harness.operationsBloc.stream,
    emits(isA<T>().having(
      (event) {
        return event.isRemote && (event.data is Iterable ? (event.data as Iterable).isNotEmpty : event.data != null);
      },
      'Should be remote and not empty',
      isTrue,
    )),
  );
}

// Authenticate user
//
// Since 'authenticate = false' is passed
// to Harness to allow for testing of
// initial states and transitions of
// OperationBloc, all tests that require
// an authenticated user must call this
//
Future _authenticate(BlocTestHarness harness, {bool exists = false}) async {
  await harness.userBloc.login(username: UNTRUSTED, password: PASSWORD);
  await Future.wait([
    expectThroughLater(
      harness.operationsBloc.stream,
      isA<OperationsLoaded>().having((event) => event.isRemote, 'Should be remote', isTrue),
    ),
    expectThroughLater(
      harness.affiliationBloc.stream,
      emits(exists
          ? isA<AffiliationUpdated>().having((event) => event.isRemote, 'Should be remote', isTrue)
          : isA<UserOnboarded>().having((event) => event.isRemote, 'Should be remote', isTrue)),
    )
  ]);
  clearInteractions(harness.operationService);
}
