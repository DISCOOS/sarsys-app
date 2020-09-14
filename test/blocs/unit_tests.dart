import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

import '../mock/incident_service_mock.dart';
import '../mock/personnel_service_mock.dart';
import '../mock/unit_service_mock.dart';
import '../mock/operation_service_mock.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc()
    ..withPersonnelBloc()
    ..withUnitBloc()
    ..install();

  test(
    'Unit bloc should be EMPTY and UNSET',
    () async {
      expect(harness.unitBloc.ouuid, isNull, reason: "SHOULD BE unset");
      expect(harness.unitBloc.units.length, 0, reason: "SHOULD BE empty");
      expect(harness.unitBloc.initialState, isA<UnitsEmpty>(), reason: "Unexpected unit state");
      expect(harness.unitBloc, emits(isA<UnitsEmpty>()));
    },
  );

  group('WHEN unitBloc is ONLINE', () {
    test('SHOULD load unit', () async {
      // Arrange
      harness.connectivity.cellular();
      Operation operation = await _prepare(harness, offline: false);
      final unit1 = harness.unitService.add(operation.uuid);
      final unit2 = harness.unitService.add(operation.uuid);

      // Act
      List<Unit> cached = await harness.unitBloc.load();
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );
      final fetched = harness.unitBloc.repo.values;

      // Assert
      expect(cached.length, 0, reason: "SHOULD contain zero units");
      expect(fetched.length, 2, reason: "SHOULD contain two units");
      expect(
        harness.unitBloc.repo.containsKey(unit1.uuid),
        isTrue,
        reason: "SHOULD contain unit ${unit1.uuid}",
      );
      expect(
        harness.unitBloc.repo.containsKey(unit2.uuid),
        isTrue,
        reason: "SHOULD contain unit ${unit2.uuid}",
      );
    });

    test('SHOULD create unit and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness, offline: false);
      final unit = UnitBuilder.create();

      // Act
      await harness.unitBloc.create(unit);
      await expectStorageStatusLater(
        unit.uuid,
        harness.unitBloc.repo,
        StorageStatus.created,
        remote: true,
      );

      // Assert
      verify(harness.unitService.create(any, any)).called(1);
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
      expect(harness.unitBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.unitBloc.repo.containsKey(unit.uuid), isTrue, reason: "SHOULD contain unit ${unit.uuid}");
      expectThrough(harness.unitBloc, isA<UnitCreated>());
    });

    test('SHOULD update unit and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness, offline: false);
      final unit = harness.unitService.add(operation.uuid);
      await harness.unitBloc.load();
      await expectDataIsNotEmpty(
        harness,
        isRemote: true,
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.update(unit.copyWith(status: UnitStatus.deployed));
      await expectStorageStatusLater(
        unit.uuid,
        harness.unitBloc.repo,
        StorageStatus.updated,
        remote: true,
      );

      // Assert
      verify(harness.unitService.update(any)).called(1);
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
      expect(harness.unitBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.unitBloc.repo.containsKey(unit.uuid), isTrue, reason: "SHOULD contain unit ${unit.uuid}");
      expectThrough(harness.unitBloc, isA<UnitUpdated>());
    });

    test('SHOULD delete unit and push to backend', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness, offline: false);
      final unit = harness.unitService.add(operation.uuid);
      await harness.unitBloc.load();
      await expectDataIsNotEmpty(
        harness,
        isRemote: true,
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.delete(unit.uuid);

      // Assert
      await expectStorageStatusLater(
        unit.uuid,
        harness.unitBloc.repo,
        StorageStatus.deleted,
        remote: true,
      );
      verify(harness.unitService.delete(any)).called(1);
      expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.unitBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expectThrough(harness.unitBloc, isA<UnitDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness, offline: false);
      harness.unitService.add(operation.uuid);
      await harness.unitBloc.load();
      await expectDataIsNotEmpty(
        harness,
        isRemote: true,
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.unload();

      // Assert0
      expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.unitBloc, isA<UnitsUnloaded>());
    });

    test('SHOULD reload one unit after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness, offline: false);
      final unit = harness.unitService.add(operation.uuid);
      await harness.unitBloc.load();
      await expectDataIsNotEmpty(
        harness,
        isRemote: true,
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.unload();
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitsUnloaded>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );

      await harness.unitBloc.load();
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitsLoaded>().having(
          (event) => event.isRemote,
          'Should be remote',
          isTrue,
        )),
      );

      // Assert
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
      expect(harness.unitBloc.repo.containsKey(unit.uuid), isTrue, reason: "SHOULD contain unit ${unit.uuid}");
    });

    test('SHOULD delete clone when personnel is deleted', () async {
      // Arrange
      await _testShouldDeleteReferenceWhenPersonnelIsDeleted(harness, offline: false);
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

  group('WHEN unitBloc is OFFLINE', () {
    test('SHOULD load as EMPTY', () async {
      // Arrange
      await _prepare(harness, offline: true);
      harness.unitService.add(harness.userBloc.userId);
      harness.unitService.add(harness.userBloc.userId);

      // Act
      List<Unit> unit = await harness.unitBloc.load();

      // Assert
      expect(unit.length, 0, reason: "SHOULD NOT contain unit");
      expect(harness.unitBloc, emits(isA<UnitsLoaded>()));
    });

    test('SHOULD create unit with state CREATED', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final unit = UnitBuilder.create();

      // Act
      await harness.unitBloc.create(unit);

      // Assert
      expect(
        harness.unitBloc.repo.states[unit.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
      expectThrough(harness.unitBloc, isA<UnitCreated>());
    });

    test('SHOULD update unit with state CREATED', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final unit1 = UnitBuilder.create(status: UnitStatus.mobilized);
      final unit2 = UnitBuilder.create(status: UnitStatus.mobilized);
      await harness.unitBloc.create(unit1);
      await harness.unitBloc.create(unit2);
      expect(harness.unitBloc.repo.length, 2, reason: "SHOULD contain two unit");

      // Act
      await harness.unitBloc.update(unit2.copyWith(status: UnitStatus.deployed));

      // Assert
      expect(
        harness.unitBloc.repo.states[unit2.uuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(
        harness.unitBloc.repo[unit1.uuid].status,
        equals(UnitStatus.mobilized),
        reason: "SHOULD be status mobilized",
      );
      expect(
        harness.unitBloc.repo[unit2.uuid].status,
        equals(UnitStatus.deployed),
        reason: "SHOULD be status deployed",
      );
      expectThrough(harness.unitBloc, isA<UnitUpdated>());
    });

    test('SHOULD delete local unit', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final unit = UnitBuilder.create();
      await harness.unitBloc.create(unit);
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.delete(unit.uuid);

      // Assert
      expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.unitBloc, isA<UnitDeleted>());
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final unit = UnitBuilder.create();
      await harness.unitBloc.create(unit);
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitCreated>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.unload();

      // Assert
      expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
      expectThrough(harness.unitBloc, isA<UnitsUnloaded>());
    });

    test('SHOULD NOT be contain after reload', () async {
      // Arrange
      await _prepare(harness, offline: true);
      final unit = UnitBuilder.create();
      await harness.unitBloc.create(unit);
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitCreated>().having(
          (event) => event.isLocal,
          'Should be local',
          isTrue,
        )),
      );
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

      // Act
      await harness.unitBloc.load();

      // Assert
      expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
      expectThroughInOrder(harness.unitBloc, [isA<UnitsLoaded>()]);
    });

    test('SHOULD delete clone when personnel is deleted', () async {
      // Arrange
      await _testShouldDeleteReferenceWhenPersonnelIsDeleted(harness, offline: true);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      await _testShouldReloadWhenOperationIsSwitched(harness, offline: true);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsDeleted(harness, offline: true);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsCancelled(harness, offline: true);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsResolved(harness, offline: true);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      await _testShouldUnloadWhenOperationIsUnloaded(harness, offline: true);
    });
  });
}

Future _testShouldDeleteReferenceWhenPersonnelIsDeleted(BlocTestHarness harness, {@required bool offline}) async {
  // Arrange
  await _prepare(harness, offline: offline);
  final p1 = await harness.personnelBloc.create(PersonnelBuilder.create());
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  final p2 = await harness.personnelBloc.create(PersonnelBuilder.create());
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  final unit = await harness.unitBloc.create(UnitBuilder.create(personnels: [p1.uuid, p2.uuid]));
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );

  // Act
  final updated = await harness.personnelBloc.delete(p2.uuid);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitUpdated>().having(
      (event) => event.isLocal,
      'Should be local',
      isTrue,
    )),
  );

  // Assert
  expect(
    harness.unitBloc.repo[unit.uuid].personnels
        .where((puuid) => puuid == updated.uuid)
        .map((puuid) => harness.personnelBloc.repo[puuid])
        .firstOrNull
        ?.status,
    isNull,
    reason: "SHOULD NOT contain $p2",
  );
}

Future _testShouldUnloadWhenOperationIsUnloaded(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness, offline: offline);
  final unit = UnitBuilder.create();
  await harness.unitBloc.create(unit);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");
  expect(harness.unitBloc.ouuid, isNotNull, reason: "SHOULD NOT be null");

  // Act
  await harness.operationsBloc.unload();
  await expectThroughLater(
    harness.operationsBloc,
    emits(isA<OperationsUnloaded>()),
  );

  // Assert
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitsUnloaded>()),
  );
  expect(harness.unitBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.unitBloc.repo.containsKey(unit.uuid),
    isFalse,
    reason: "SHOULD NOT contain unit ${unit.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsResolved(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final unit = UnitBuilder.create();
  await harness.unitBloc.create(unit);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(status: OperationStatus.completed),
  );

  // Assert
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitsUnloaded>()),
  );
  expect(harness.unitBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.unitBloc.repo.containsKey(unit.uuid),
    isFalse,
    reason: "SHOULD NOT contain unit ${unit.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsCancelled(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final unit = UnitBuilder.create();
  await harness.unitBloc.create(unit);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );

  expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(
      status: OperationStatus.completed,
      resolution: OperationResolution.cancelled,
    ),
  );

  // Assert
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitsUnloaded>()),
  );
  expect(harness.unitBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.unitBloc.repo.containsKey(unit.uuid),
    isFalse,
    reason: "SHOULD NOT contain unit ${unit.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsDeleted(BlocTestHarness harness, {@required bool offline}) async {
  final operation = await _prepare(harness, offline: offline);
  final unit = UnitBuilder.create();
  await harness.unitBloc.create(unit);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

  // Act
  await harness.operationsBloc.delete(operation.uuid);

  // Assert
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitsUnloaded>()),
  );
  expect(harness.unitBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.unitBloc.repo.containsKey(unit.uuid),
    isFalse,
    reason: "SHOULD NOT contain unit ${unit.uuid}",
  );
}

Future _testShouldReloadWhenOperationIsSwitched(BlocTestHarness harness, {@required bool offline}) async {
  await _prepare(harness, offline: offline);
  final unit = UnitBuilder.create();
  await harness.unitBloc.create(unit);
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  expect(harness.unitBloc.repo.length, 1, reason: "SHOULD contain one unit");

  // Act
  final incident = IncidentBuilder.create();
  final operation2 = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );
  await expectThroughLater(
    harness.operationsBloc,
    emits(isA<OperationCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );

  // Assert
  await expectThroughInOrderLater(
    harness.unitBloc,
    [isA<UnitsUnloaded>(), isA<UnitsLoaded>()],
  );
  expect(harness.unitBloc.ouuid, operation2.uuid, reason: "SHOULD change to ${operation2.uuid}");
  expect(harness.unitBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.unitBloc.repo.containsKey(unit.uuid),
    isFalse,
    reason: "SHOULD NOT contain unit ${unit.uuid}",
  );
}

/// Prepare blocs for testing
Future<Operation> _prepare(BlocTestHarness harness, {@required bool offline}) async {
  await harness.userBloc.login(
    username: harness.username,
    password: harness.password,
  );

  if (offline) {
    harness.connectivity.offline();
  } else {
    harness.connectivity.cellular();
  }

  // Wait for user to onboard
  await expectThroughLater(
    harness.affiliationBloc,
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

  // Create operation
  final incident = IncidentBuilder.create();
  final operation = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
  );

  // Prepare OperationBloc
  await expectThroughLater(harness.operationsBloc, emits(isA<OperationSelected>()));
  expect(
    harness.operationsBloc.isUnselected,
    isFalse,
    reason: "SHOULD NOT be unset",
  );

  // Prepare UnitBloc
  await expectThroughLater(harness.unitBloc, emits(isA<UnitsLoaded>()));
  expect(
    harness.unitBloc.ouuid,
    operation.uuid,
    reason: "SHOULD depend on operation ${operation.uuid}",
  );

  // Await User to be mobilized
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelCreated>().having(
      (event) => event.isRemote,
      'Should be ${offline ? 'local' : 'remote'}',
      !offline,
    )),
  );
  // Verify only user exists
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

Future<void> expectDataIsEmpty<T extends UnitState>(
  BlocTestHarness harness, {
  @required bool isRemote,
}) {
  return expectThroughLater(
    harness.unitBloc,
    emits(isA<T>().having(
      (event) {
        return event.isRemote == isRemote &&
            (event.data is Iterable ? (event.data as Iterable).isEmpty : event.data == null);
      },
      'Should be ${isRemote ? 'remote' : 'local'} and not empty',
      isTrue,
    )),
  );
}

Future<void> expectDataIsNotEmpty<T extends UnitState>(
  BlocTestHarness harness, {
  @required bool isRemote,
}) {
  return expectThroughLater(
    harness.unitBloc,
    emits(isA<T>().having(
      (event) {
        return event.isRemote == isRemote &&
            (event.data is Iterable ? (event.data as Iterable).isNotEmpty : event.data != null);
      },
      'Should be ${isRemote ? 'remote' : 'local'} and not empty',
      isTrue,
    )),
  );
}
