import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/personnel_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc()
    ..withPersonnelBloc()
    ..install();

  test(
    'Personnel bloc should be EMPTY and UNSET',
    () async {
      expect(harness.personnelBloc.ouuid, isNull, reason: "SHOULD BE unset");
      expect(harness.personnelBloc.personnels.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.initialState, isA<PersonnelsEmpty>(), reason: "Unexpected personnel state");
      expect(harness.personnelBloc, emits(isA<PersonnelsEmpty>()));
    },
  );

  group('WHEN personnelBloc is ONLINE', () {
    test('SHOULD load personnel', () async {
      // Arrange
      harness.connectivity.cellular();
      Operation operation = await _prepare(harness);
      final personnel1 = harness.personnelService.add(operation.uuid);
      final personnel2 = harness.personnelService.add(operation.uuid);

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
      final operation = await _prepare(harness);
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
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update operation and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final personnel = harness.personnelService.add(operation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.update(personnel.copyWith(status: PersonnelStatus.onscene));

      // Assert
      verify(harness.personnelService.update(any)).called(1);
      expectStorageStatus(
        harness.personnelBloc.repo.states[personnel.uuid],
        StorageStatus.updated,
        remote: true,
      );
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.personnelBloc.repo.containsKey(personnel.uuid), isTrue,
          reason: "SHOULD contain personnel ${personnel.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelUpdated>());
    });

    test('SHOULD delete personnel and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final personnel = harness.personnelService.add(operation.uuid);
      await harness.personnelBloc.load();
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.delete(personnel.uuid);

      // Assert
      verify(harness.personnelService.delete(any)).called(1);
      expect(
        harness.personnelBloc.repo.states[personnel.uuid],
        isNull,
        reason: "SHOULD HAVE NO status",
      );
      expect(harness.personnelBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT BE unset");
      expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expectThrough(harness.personnelBloc, isA<PersonnelDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      harness.personnelService.add(operation.uuid);
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
      final operation = await _prepare(harness);
      final personnel = harness.personnelService.add(operation.uuid);
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

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
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
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expectThrough(harness.personnelBloc, isA<PersonnelCreated>());
    });

    test('SHOULD update personnel with state CREATED', () async {
      // Arrange
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel1 = PersonnelBuilder.create(status: PersonnelStatus.alerted);
      final personnel2 = PersonnelBuilder.create(status: PersonnelStatus.alerted);
      await harness.personnelBloc.create(personnel1);
      await harness.personnelBloc.create(personnel2);
      expect(harness.personnelBloc.repo.length, 2, reason: "SHOULD contain two personnel");

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
      harness.connectivity.offline();
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.delete(personnel.uuid);

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
      await _prepare(harness);
      final personnel = PersonnelBuilder.create();
      await harness.personnelBloc.create(personnel);
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

      // Act
      await harness.personnelBloc.unload();
      await harness.personnelBloc.load();

      // Assert
      expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
      expectThroughInOrder(harness.personnelBloc, [isA<PersonnelsUnloaded>(), isA<PersonnelsLoaded>()]);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.offline();
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
    });
  });
}

Future _testShouldUnloadWhenOperationIsUnloaded(BlocTestHarness harness) async {
  await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");
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

Future _testShouldUnloadWhenOperationIsResolved(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

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

Future _testShouldUnloadWhenOperationIsCancelled(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

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

Future _testShouldUnloadWhenOperationIsDeleted(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

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

Future _testShouldReloadWhenOperationIsSwitched(BlocTestHarness harness) async {
  await _prepare(harness);
  final personnel = PersonnelBuilder.create();
  await harness.personnelBloc.create(personnel);
  expect(harness.personnelBloc.repo.length, 1, reason: "SHOULD contain one personnel");

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
Future<Operation> _prepare(BlocTestHarness harness) async {
  // A user must be authenticated
  expect(harness.userBloc.isAuthenticated, isTrue, reason: "SHOULD be authenticated");

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
