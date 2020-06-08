import 'dart:async';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/streams.dart';
import 'package:SarSys/mock/device_service_mock.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/mock/personnel_service_mock.dart';
import 'package:SarSys/mock/tracking_service_mock.dart';
import 'package:SarSys/mock/unit_service_mock.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withOperationBloc()
    ..withTrackingBloc()
    ..withPersonnelBloc()
    ..withDeviceBloc()
    ..withUnitBloc()
    ..withTrackingBloc()
    ..install();

  test(
    'TrackingBloc should be EMPTY and UNSET',
    () async {
      expect(harness.trackingBloc.ouuid, isNull, reason: "SHOULD BE unset");
      expect(harness.trackingBloc.trackings.length, 0, reason: "SHOULD BE empty");
      expect(harness.trackingBloc.initialState, isA<TrackingsEmpty>(), reason: "Unexpected tracking state");
      expect(harness.trackingBloc, emits(isA<TrackingsEmpty>()));
    },
  );

  group('WHEN TrackingBloc has data', () {
    test('SHOULD contain devices', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);

      // Act
      final d1 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d2 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      await Future.delayed(Duration(milliseconds: 1));

      final p1 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt1 = await _attachDeviceToTrackable(harness, p1, d1);
      final p2 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt2 = await _attachDeviceToTrackable(harness, p2, d2);
      final p3 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt3 = await _attachDeviceToTrackable(harness, p3, d3);
      await Future.delayed(Duration(milliseconds: 1));

      // Act and assert
      expect(harness.trackingBloc.devices(pt1.uuid), equals([d1]), reason: "SHOULD contain d1");
      expect(harness.trackingBloc.devices(pt2.uuid), equals([d2]), reason: "SHOULD contain d2");
      expect(harness.trackingBloc.devices(pt3.uuid), equals([d3]), reason: "SHOULD contain d3");
    });

    test('SHOULD query and match personnels', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);

      // Act
      final d1 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d2 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));

      final p1 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt1 = await _attachDeviceToTrackable(harness, p1, d1);
      final p2 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt2 = await _attachDeviceToTrackable(harness, p2, d2);
      final p3 = await harness.personnelBloc.create(PersonnelBuilder.create());
      final pt3 = await _attachDeviceToTrackable(harness, p3, d3);

      // Assert personnel trackings
      final personnels = harness.trackingBloc.personnels;
      expect(personnels.contains(p1), isTrue, reason: "SHOULD contain p1");
      expect(personnels.contains(p2), isTrue, reason: "SHOULD contain p2");
      expect(personnels.contains(p3), isTrue, reason: "SHOULD contain p3");
      expect(personnels.trackedBy(pt1.uuid), equals(p1), reason: "SHOULD return p1");
      expect(personnels.trackedBy(pt2.uuid), equals(p2), reason: "SHOULD return p2");
      expect(personnels.trackedBy(pt3.uuid), equals(p3), reason: "SHOULD return p3");
      expect(personnels.find(d1), equals(p1), reason: "SHOULD return p1");
      expect(personnels.find(d2), equals(p2), reason: "SHOULD return p2");
      expect(personnels.find(d3), equals(p3), reason: "SHOULD return p3");
      expect(personnels.elementAt(p1), equals(pt1), reason: "SHOULD return pt1");
      expect(personnels.elementAt(p2), equals(pt2), reason: "SHOULD return pt2");
      expect(personnels.elementAt(p3), equals(pt3), reason: "SHOULD return pt3");
      expect(personnels.devices().keys, contains(d1.uuid), reason: "SHOULD contain d1");
      expect(personnels.devices().keys, contains(d2.uuid), reason: "SHOULD contain d2");
      expect(personnels.devices().keys, contains(d3.uuid), reason: "SHOULD contain d3");
    });

    test('SHOULD query and match units', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);

      // Act
      final d1 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d2 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));
      final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available));

      final p1 = await harness.personnelBloc.create(PersonnelBuilder.create());
      await _attachDeviceToTrackable(harness, p1, d1);
      final p2 = await harness.personnelBloc.create(PersonnelBuilder.create());
      await _attachDeviceToTrackable(harness, p2, d2);
      final p3 = await harness.personnelBloc.create(PersonnelBuilder.create());
      await _attachDeviceToTrackable(harness, p3, d3);

      final u1 = await harness.unitBloc.create(UnitBuilder.create(personnels: [p1]));
      final u2 = await harness.unitBloc.create(UnitBuilder.create(personnels: [p2]));
      final u3 = await harness.unitBloc.create(UnitBuilder.create(personnels: [p3]));

      final ut1 = await harness.trackingBloc.attach(u1.tracking.uuid, personnels: [p1]);
      final ut2 = await harness.trackingBloc.attach(u2.tracking.uuid, personnels: [p2]);
      final ut3 = await harness.trackingBloc.attach(u3.tracking.uuid, personnels: [p3]);

      // Assert unit trackings
      final units = harness.trackingBloc.units;
      expect(units.contains(u1), isTrue, reason: "SHOULD contain u1");
      expect(units.contains(u2), isTrue, reason: "SHOULD contain u2");
      expect(units.contains(u3), isTrue, reason: "SHOULD contain u3");
      expect(units.trackedBy(ut1.uuid), equals(u1), reason: "SHOULD return u1");
      expect(units.trackedBy(ut2.uuid), equals(u2), reason: "SHOULD return u2");
      expect(units.trackedBy(ut3.uuid), equals(u3), reason: "SHOULD return u3");
      expect(units.find(p1), equals(u1), reason: "SHOULD return u1");
      expect(units.find(p2), equals(u2), reason: "SHOULD return u2");
      expect(units.find(p3), equals(u3), reason: "SHOULD return u3");
      expect(units.elementAt(u1), equals(ut1), reason: "SHOULD return ut1");
      expect(units.elementAt(u2), equals(ut2), reason: "SHOULD return ut2");
      expect(units.elementAt(u3), equals(ut3), reason: "SHOULD return ut3");
      expect(units.personnels().keys, contains(p1.uuid), reason: "SHOULD return p1");
      expect(units.personnels().keys, contains(p1.uuid), reason: "SHOULD return p2");
      expect(units.personnels().keys, contains(p1.uuid), reason: "SHOULD return p3");
      expect(units.devices().isEmpty, isTrue, reason: "SHOULD be empty");
      expect(units.devices().isEmpty, isTrue, reason: "SHOULD be empty");
      expect(units.devices().isEmpty, isTrue, reason: "SHOULD be empty");
    });
  });

  group('WHEN TrackingBloc is ONLINE', () {
    test('SHOULD load trackings', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldLoadTrackings(harness);
    });

    test('SHOULD create unit tracking automatically', () async {
      // Arrange
      harness.connectivity.cellular();
      final unit = UnitBuilder.create(personnels: [
        PersonnelBuilder.create(),
        PersonnelBuilder.create(),
      ]);

      // Act and assert
      final state = await _shouldCreateTrackingAutomatically<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(unit),
      );

      // Assert unit tracking specifics
      final tracking = state.value;
      expect(tracking.sources.length, 2, reason: "SHOULD contain 2 sources");
      expect(
        tracking.sources.map((source) => source.uuid),
        equals(unit.personnels.map((p) => p.uuid)),
        reason: "SHOULD match personnel uuids in unit",
      );
    });

    test('SHOULD create personnel tracking automatically', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );

      // Assert personnel tracking specifics
      final tracking = state.value;
      expect(tracking.sources.length, 0, reason: "SHOULD NOT contain sources");
    });

    test('SHOULD create tracking for active units only', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _shouldCreateTrackingForActiveUnitsOnly<Unit>(harness, act: () async {
        await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Retired));
        return await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized));
      });
    });

    test('SHOULD create tracking for active personnels only', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _shouldCreateTrackingForActiveUnitsOnly<Personnel>(harness, act: () async {
        await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Retired));
        return await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized));
      });
    });

    test('SHOULD update unit tracking when device is added', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
      );
    });

    test('SHOULD update unit tracking when device is removed', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create(
          status: UnitStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update unit tracking when personnel is added', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelAdded(harness, puuid: Uuid().v4());
    });

    test('SHOULD update unit tracking when personnel is removed', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelRemoved(harness, puuid: Uuid().v4());
    });

    test('SHOULD update unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD replace unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD attach to unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD delete from unit tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD update personnel tracking when device is added', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
          status: PersonnelStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update personnel tracking when device is removed', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
          status: PersonnelStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD replace personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD attach to personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD delete from personnel tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD throw when attaching sources already tracked by unit', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _shouldThrowWhenAttachingSourcesAlreadyTracked<Unit>(harness, act: () async {
        return [
          await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
          await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
        ];
      });
    });

    test('SHOULD throw when attaching sources already tracked by personnel', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _shouldThrowWhenAttachingSourcesAlreadyTracked<Personnel>(harness, act: () async {
        return [
          await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized)),
          await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized)),
        ];
      });
    });

    test('SHOULD close unit tracking automatically when RETIRED', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldCloseTrackingAutomatically<Unit>(
        harness,
        arrange: (ouuid) async => await harness.unitBloc.create(
          UnitBuilder.create(),
        ),
        act: (unit) async {
          await harness.unitBloc.update(
            unit.copyWith(status: UnitStatus.Retired),
          );
          await expectThroughLater(harness.unitBloc, emits(isA<UnitUpdated>()));
        },
      );
    });

    test('SHOULD close personnel tracking automatically when RETIRED', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldCloseTrackingAutomatically<Personnel>(
        harness,
        arrange: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
        act: (personnel) async {
          await harness.personnelBloc.update(
            personnel.copyWith(status: PersonnelStatus.Retired),
          );
          await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelUpdated>()));
        },
      );
    });

    test('SHOULD reopen closed tracking automatically when unit is MOBILIZED', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReopenClosedUnitTrackingAutomatically(harness, UnitStatus.Mobilized);
    });

    test('SHOULD reopen closed tracking automatically when unit is DEPLOYED', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReopenClosedUnitTrackingAutomatically(harness, UnitStatus.Deployed);
    });

    test('SHOULD reopen closed tracking automatically when personnel is MOBILIZED', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReopenClosedPersonnelTrackingAutomatically(harness, PersonnelStatus.Mobilized);
    });

    test('SHOULD reopen closed tracking automatically when personnel is ONSCENE', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReopenClosedPersonnelTrackingAutomatically(harness, PersonnelStatus.OnScene);
    });

    test('SHOULD delete unit tracking automatically', () async {
      // Arrange
      harness.connectivity.cellular();
      final unit = UnitBuilder.create(personnels: [
        PersonnelBuilder.create(),
        PersonnelBuilder.create(),
      ]);
      final state = await _shouldCreateTrackingAutomatically<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(unit),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      await _shouldDeleteTrackingAutomatically<Unit>(
        harness,
        tuuid,
        act: (tuuid) => harness.unitBloc.delete(unit.uuid),
      );
    });

    test('SHOULD delete personnel tracking automatically', () async {
      // Arrange
      harness.connectivity.cellular();
      final personnel = PersonnelBuilder.create();
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(personnel),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      await _shouldDeleteTrackingAutomatically<Personnel>(
        harness,
        tuuid,
        act: (tuuid) => harness.personnelBloc.delete(personnel.uuid),
      );
    });

    test('SHOULD update tracking on remote change', () async {
      // Arrange
      harness.connectivity.cellular();
      await _prepare(harness);

      // Act LOCALLY
      final unit = await harness.unitBloc.create(UnitBuilder.create());
      final tuuid = unit.tracking.uuid;

      // Assert local state
      await _assertTrackingState<TrackingCreated>(
        harness,
        tuuid,
        StorageStatus.created,
        remote: false,
      );

      // Act - Simulate backend
      final tracking = harness.trackingBloc.repo[tuuid];
      await _notify(harness, TrackingMessage.created(tracking));

      // Assert remote state
      await _assertTrackingState<TrackingCreated>(
        harness,
        tuuid,
        StorageStatus.created,
        remote: true,
      );
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      harness.trackingService.add(operation.uuid);
      await harness.trackingBloc.load();
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");

      // Act
      await harness.trackingBloc.unload();

      // Assert
      expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.trackingBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expectThrough(harness.trackingBloc, isA<TrackingsUnloaded>());
    });

    test('SHOULD reload one tracking after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final operation = await _prepare(harness);
      final tracking = harness.trackingService.add(operation.uuid);
      await harness.trackingBloc.load();
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");

      // Act
      await harness.trackingBloc.unload();
      await harness.trackingBloc.load();

      // Assert
      expect(harness.trackingBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expect(
        harness.trackingBloc.repo.containsKey(tracking.uuid),
        isTrue,
        reason: "SHOULD contain tracking ${tracking.uuid}",
      );
      expectThroughInOrder(harness.trackingBloc, [isA<TrackingsUnloaded>(), isA<TrackingsLoaded>()]);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
    });
  }, skip: false);

  group('WHEN TrackingBloc is OFFLINE', () {
    test('SHOULD NOT load trackings', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldLoadTrackings(harness);
    });

    test('SHOULD create unit tracking automatically locally only', () async {
      // Arrange
      harness.connectivity.offline();
      final unit = UnitBuilder.create(personnels: [
        PersonnelBuilder.create(),
        PersonnelBuilder.create(),
      ]);

      // Act and assert
      final state = await _shouldCreateTrackingAutomatically<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(unit),
      );

      // Assert unit tracking specifics
      final tracking = state.value;
      expect(tracking.sources.length, 2, reason: "SHOULD contain 2 sources");
      expect(
        tracking.sources.map((source) => source.uuid),
        equals(unit.personnels.map((p) => p.uuid)),
        reason: "SHOULD match personnel uuids in unit",
      );
    });

    test('SHOULD create personnel tracking automatically', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );

      // Assert personnel tracking specifics
      final tracking = state.value;
      expect(tracking.sources.length, 0, reason: "SHOULD NOT contain sources");
    });

    test('SHOULD create tracking for active units only', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _shouldCreateTrackingForActiveUnitsOnly<Unit>(harness, act: () async {
        await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Retired));
        return await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized));
      });
    });

    test('SHOULD create tracking for active personnels only', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _shouldCreateTrackingForActiveUnitsOnly<Personnel>(harness, act: () async {
        await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Retired));
        return await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized));
      });
    });

    test('SHOULD update unit tracking when device is added', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
      );
    });

    test('SHOULD update unit tracking when device is removed', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create(
          status: UnitStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update unit tracking when personnel is added', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelAdded(harness, puuid: Uuid().v4());
    });

    test('SHOULD update unit tracking when personnel is removed', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelRemoved(harness, puuid: Uuid().v4());
    });

    test('SHOULD update unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD replace unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD attach to unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD delete from unit tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD update personnel tracking when device is added', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
          status: PersonnelStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update personnel tracking when device is removed', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
          status: PersonnelStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD replace personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD attach to personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD delete from personnel tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD throw when attaching sources already tracked by unit', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _shouldThrowWhenAttachingSourcesAlreadyTracked<Unit>(harness, act: () async {
        return [
          await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
          await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
        ];
      });
    });

    test('SHOULD throw when attaching sources already tracked by personnel', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _shouldThrowWhenAttachingSourcesAlreadyTracked<Personnel>(harness, act: () async {
        return [
          await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized)),
          await harness.personnelBloc.create(PersonnelBuilder.create(status: PersonnelStatus.Mobilized)),
        ];
      });
    });

    test('SHOULD close unit tracking automatically when RETIRED locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldCloseTrackingAutomatically<Unit>(
        harness,
        arrange: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
        act: (unit) async {
          await harness.unitBloc.update(
            unit.copyWith(status: UnitStatus.Retired),
          );
          await expectThroughLater(harness.unitBloc, emits(isA<UnitUpdated>()));
        },
      );
    });

    test('SHOULD close personnel tracking automatically when RETIRED locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldCloseTrackingAutomatically<Personnel>(
        harness,
        arrange: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
        act: (personnel) async {
          await harness.personnelBloc.update(
            personnel.copyWith(status: PersonnelStatus.Retired),
          );
          await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelUpdated>()));
        },
      );
    });

    test('SHOULD reopen closed tracking automatically when unit is MOBILIZED locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReopenClosedUnitTrackingAutomatically(
        harness,
        UnitStatus.Mobilized,
      );
    });

    test('SHOULD reopen closed tracking automatically when unit is DEPLOYED locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReopenClosedUnitTrackingAutomatically(harness, UnitStatus.Deployed);
    });

    test('SHOULD reopen closed tracking automatically when personnel is MOBILIZED locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReopenClosedPersonnelTrackingAutomatically(harness, PersonnelStatus.Mobilized);
    });

    test('SHOULD reopen closed tracking automatically when personnel is ONSCENE locally', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReopenClosedPersonnelTrackingAutomatically(harness, PersonnelStatus.OnScene);
    });

    test('SHOULD delete unit tracking automatically locally', () async {
      // Arrange
      final unit = UnitBuilder.create(personnels: [
        PersonnelBuilder.create(),
        PersonnelBuilder.create(),
      ]);
      final state = await _shouldCreateTrackingAutomatically<Unit>(
        harness,
        act: (ouuid) async => await harness.unitBloc.create(unit),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      harness.connectivity.offline();
      await _shouldDeleteTrackingAutomatically<Unit>(
        harness,
        tuuid,
        act: (tuuid) => harness.unitBloc.delete(unit.uuid),
      );
    });

    test('SHOULD delete personnel tracking automatically locally', () async {
      // Arrange
      final personnel = PersonnelBuilder.create();
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (ouuid) async => await harness.personnelBloc.create(personnel),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      harness.connectivity.offline();
      await _shouldDeleteTrackingAutomatically<Personnel>(
        harness,
        tuuid,
        act: (tuuid) => harness.personnelBloc.delete(personnel.uuid),
      );
    });

    test('SHOULD update tracking on remote change', () async {
      // Arrange
      harness.connectivity.offline();
      final operation = await _prepare(harness);

      // Act LOCALLY
      final unit = await harness.unitBloc.create(UnitBuilder.create());
      final tuuid = unit.tracking.uuid;

      // Assert CREATED
      await expectThroughLater(
        harness.trackingBloc,
        emits(isA<TrackingCreated>()),
        close: false,
      );
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expect(
        harness.trackingBloc.repo.states[tuuid].status,
        equals(StorageStatus.created),
        reason: "SHOULD HAVE status CREATED",
      );
      expect(harness.trackingBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");

      // Act REMOTELY
      final tracking = harness.trackingBloc.repo[tuuid];
      await _notify(harness, TrackingMessage.created(tracking));

      // Assert PUSHED
      await expectThroughLater(
        harness.trackingBloc,
        emitsInAnyOrder([isA<TrackingCreated>()]),
        close: false,
      );
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expectStorageStatus(
        harness.trackingBloc.repo.states[tuuid],
        StorageStatus.created,
        remote: true,
      );
      expect(harness.trackingBloc.ouuid, operation.uuid, reason: "SHOULD depend on ${operation.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.offline();
      final operation = await _prepare(harness);
      final tracking = TrackingBuilder.create();
      await _ensurePersonnelWithTracking(harness, operation, tracking);

      // Act
      await harness.trackingBloc.unload();

      // Assert
      expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
      expect(harness.trackingBloc.isUnset, isTrue, reason: "SHOULD BE unset");
      expectThrough(harness.trackingBloc, isA<TrackingsUnloaded>());
    });

    test('SHOULD not reload trackings after unload', () async {
      // Arrange
      harness.connectivity.offline();
      final operation = await _prepare(harness);
      final tracking = TrackingBuilder.create();
      await _ensurePersonnelWithTracking(harness, operation, tracking);

      // Act
      await harness.trackingBloc.unload();
      await harness.trackingBloc.load();

      // Assert
      expect(harness.trackingBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expect(
        harness.trackingBloc.repo.containsKey(tracking.uuid),
        isTrue,
        reason: "SHOULD contain tracking ${tracking.uuid}",
      );
      expectThroughInOrder(harness.trackingBloc, [isA<TrackingsUnloaded>(), isA<TrackingsLoaded>()]);
    });

    test('SHOULD reload when operation is switched', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldReloadWhenOperationIsSwitched(harness);
    });

    test('SHOULD unload when operation is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsDeleted(harness);
    });

    test('SHOULD unload when operation is cancelled', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsCancelled(harness);
    });

    test('SHOULD unload when operation is resolved', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsResolved(harness);
    });

    test('SHOULD unload when operations are unloaded', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenOperationIsUnloaded(harness);
    });
  });
}

FutureOr<Tracking> _attachDeviceToTrackable(BlocTestHarness harness, Trackable trackable, Device device) async =>
    await waitThroughStateWithData<TrackingCreated, Tracking>(
      harness.trackingBloc,
      map: (state) => state.data,
      test: (state) => trackable.tracking.uuid == state.data.uuid,
      act: (t) async => await harness.trackingBloc.attach(t.uuid, devices: [device]),
    );

Future<Tracking> _shouldUpdateTrackingDirectly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final state = await _shouldCreateTrackingAutomatically<T>(
    harness,
    act: act,
  );
  final t1 = state.value;
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);

  // Act
  final t2 = await harness.trackingBloc.update(t1.uuid, position: p2, status: TrackingStatus.tracking);

  // Assert
  expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.status, equals(TrackingStatus.paused), reason: "SHOULD be status paused");
  expect(t2.history.length, 1, reason: "SHOULD be length 1");
  expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.history.last.source, equals(PositionSource.manual), reason: "SHOULD be manual");

  return t2;
}

Future<Tracking> _shouldReplaceTrackingDirectly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldUpdateTrackingWhenDeviceAdded<T>(
    harness,
    act: act,
  );
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d2 = await harness.deviceBloc.create(DeviceBuilder.create(
    status: DeviceStatus.Available,
    position: p2,
  ));

  // Act
  final t2 = await harness.trackingBloc.replace(t1.uuid, position: p2, devices: [d2]);

  // Assert
  expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  expect(t2.history.length, 2, reason: "SHOULD be length 1");
  expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.history.last.source, equals(PositionSource.manual), reason: "SHOULD be manual");
  expect(t2.sources.length, 1, reason: "SHOULD be length 1");
  expect(t2.sources.last.uuid, equals(d2.uuid), reason: "SHOULD be uuid of d2");
  expect(t2.tracks.length, 2, reason: "SHOULD be length 2");
  expect(t2.tracks.last.source.uuid, equals(d2.uuid), reason: "SHOULD be uuid of d2");
  expect(t2.tracks.last.positions.length, 1, reason: "SHOULD be length 1");
  expect(t2.tracks.last.positions.last.geometry, p2.geometry, reason: "SHOULD be position p2");

  return t2;
}

Future<Tracking> _shouldAttachToTrackingDirectly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldUpdateTrackingWhenDeviceAdded<T>(
    harness,
    act: act,
  );
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d2 = await harness.deviceBloc.create(DeviceBuilder.create(
    status: DeviceStatus.Available,
    position: p2,
  ));

  // Act
  final t2 = await harness.trackingBloc.attach(t1.uuid, position: p2, devices: [d2]);

  // Assert
  expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  expect(t2.history.length, 2, reason: "SHOULD be length 2");
  expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.history.last.source, equals(PositionSource.manual), reason: "SHOULD be manual");
  expect(t2.sources.length, 2, reason: "SHOULD be length 2");
  expect(t2.sources.last.uuid, equals(d2.uuid), reason: "SHOULD be uuid of d2");
  expect(t2.tracks.length, 2, reason: "SHOULD be length 2");
  expect(t2.tracks.last.source.uuid, equals(d2.uuid), reason: "SHOULD be uuid of d2");
  expect(t2.tracks.last.positions.length, 1, reason: "SHOULD be length 1");
  expect(t2.tracks.last.positions.last.geometry, p2.geometry, reason: "SHOULD be position p2");

  return t2;
}

Future<Tracking> _shouldDetachFromTrackingDirectly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final d1 = harness.deviceBloc.repo[t1.sources.last.uuid];
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);

  // Act
  final t2 = await harness.trackingBloc.detach(t1.uuid, position: p2, devices: [d1]);

  // Assert
  expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  expect(t2.history.length, 3, reason: "SHOULD be length 3");
  expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.history.last.source, equals(PositionSource.manual), reason: "SHOULD be manual");
  expect(t2.sources.length, 1, reason: "SHOULD be length 2");
  expect(t2.sources.map((e) => e.uuid), isNot(contains(d1.uuid)), reason: "SHOULD NOT contain uuid of d1");
  expect(t2.tracks.length, 2, reason: "SHOULD be length 2");
  expect(t2.tracks.map((e) => e.source.uuid), contains(d1.uuid), reason: "SHOULD contain uuid of d1");
  expect(
    t2.tracks.firstWhere((e) => d1.uuid == e.source.uuid).status,
    equals(TrackStatus.detached),
    reason: "SHOULD BE detached",
  );

  return t2;
}

Future<Tracking> _shouldDetachFromTrackingWhenDeviceUnavailable<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final p3 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available, position: p3));
  final t2 = await harness.trackingBloc.attach(t1.uuid, devices: [d3]);
  expect(t2.history.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.map((e) => e.uuid), contains(d3.uuid), reason: "SHOULD contain uuid of d3");
  expect(t2.tracks.length, 3, reason: "SHOULD be length 3");
  expect(t2.tracks.map((e) => e.source.uuid), contains(d3.uuid), reason: "SHOULD contain uuid of d3");

  // Act
  await harness.deviceBloc.detach(d3);

  // Assert
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingUpdated>()), close: false);
  final t3 = harness.trackingBloc.repo[t2.uuid];

  expect(t3.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  expect(t3.history.length, 3, reason: "SHOULD be length 3");
  expect(t3.sources.length, 2, reason: "SHOULD be length 2");
  expect(t3.sources.map((e) => e.uuid), isNot(contains(d3.uuid)), reason: "SHOULD NOT contain uuid of d3");
  expect(t3.tracks.length, 3, reason: "SHOULD be length 3");
  expect(t3.tracks.map((e) => e.source.uuid), contains(d3.uuid), reason: "SHOULD contain uuid of d3");
  expect(t3.tracks.last.source.uuid, equals(d3.uuid), reason: "SHOULD contain uuid of d3");
  expect(t3.tracks.last.status, equals(TrackStatus.detached), reason: "SHOULD be detached");

  return t3;
}

Future<Tracking> _shouldDeleteFromTrackingWhenDeviceDeleted<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final p3 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available, position: p3));
  final t2 = await harness.trackingBloc.attach(t1.uuid, devices: [d3]);
  expect(t2.history.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.map((e) => e.uuid), contains(d3.uuid), reason: "SHOULD NOT contain uuid of d3");
  expect(t2.tracks.length, 3, reason: "SHOULD be length 3");
  expect(t2.tracks.map((e) => e.source.uuid), contains(d3.uuid), reason: "SHOULD NOT contain uuid of d3");

  // Act
  await harness.deviceBloc.delete(d3.uuid);

  // Assert
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingUpdated>()), close: false);
  final t3 = harness.trackingBloc.repo[t2.uuid];

  expect(t3.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  // Last position is recalculated on delete
  // which adds a new position to history,
  // increasing length to 4. This behavior
  // will change when recalculation from
  // first position in each track is
  // implemented and the test will
  // -- fail here --.
  expect(t3.history.length, 4, reason: "SHOULD be length 4");
  expect(t3.sources.length, 2, reason: "SHOULD be length 2");
  expect(t3.sources.map((e) => e.uuid), isNot(contains(d3.uuid)), reason: "SHOULD contain uuid of d3");
  expect(t3.tracks.length, 2, reason: "SHOULD be length 2");
  expect(t3.tracks.map((e) => e.source.uuid), isNot(contains(d3.uuid)), reason: "SHOULD contain uuid of d3");

  return t3;
}

Future _shouldCreateTrackingForActiveUnitsOnly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function() act,
}) async {
  await _prepare(harness);

  // Act
  final trackable = await act();

  // Assert
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingCreated>()), close: false);
  expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain 1 tracking");
  expect(
    harness.trackingBloc.repo.containsKey(trackable.tracking.uuid),
    isTrue,
    reason: "SHOULD contain tracking for trackable ${trackable.uuid}",
  );
}

Future _shouldThrowWhenAttachingSourcesAlreadyTracked<T extends Trackable>(
  BlocTestHarness harness, {
  Future<List<T>> Function() act,
}) async {
  // Arrange
  await _prepare(harness);
  // First position is (1,1)
  final p1 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);

  // Act
  final trackables = await act();
  expect(trackables.length, 2, reason: "SHOULD contain exactly two ${typeOf<T>()}s");
  expect(
    trackables.first,
    isNot(equals(trackables.last)),
    reason: "SHOULD contain two unique ${typeOf<T>()}s",
  );
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingCreated>()), close: false);
  final first = harness.trackingBloc.repo[trackables.first.tracking.uuid];
  final d1 = await harness.deviceBloc.create(DeviceBuilder.create(position: p1, status: DeviceStatus.Available));
  await harness.trackingBloc.attach(first.uuid, devices: [d1]);
  final last = harness.trackingBloc.repo[trackables.last.tracking.uuid];

  // Assert
  await expectLater(
    () => harness.trackingBloc.attach(last.uuid, devices: [d1]),
    throwsA(
      isA<TrackingSourceAlreadyTrackedException>(),
    ),
    reason: "SHOULD throw TrackingError",
  );
}

Future _shouldDeleteTrackingAutomatically<T extends Trackable>(
  BlocTestHarness harness,
  String tuuid, {
  Future<T> Function(String ouuid) act,
}) async {
  // Act
  await act(tuuid);

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingDeleted>()),
    close: false,
  );

  // Only deleted locally (which is good enough for this test)
  expect(
    harness.trackingBloc.repo[tuuid],
    isNotNull,
    reason: "SHOULD contain tracking $tuuid",
  );
  expect(
    harness.trackingBloc.repo[tuuid].status,
    TrackingStatus.closed,
    reason: "SHOULD be closed",
  );
  expect(
    harness.trackingBloc.repo.states[tuuid].status,
    StorageStatus.deleted,
    reason: "SHOULD be deleted",
  );
}

Future _shouldUpdateTrackingWhenDeviceRemoved<T extends Trackable>(
  BlocTestHarness harness, {
  @required Future<T> Function(String ouuid) act,
}) async {
  final t1 = await _shouldUpdateTrackingWhenDeviceAdded<T>(
    harness,
    act: act,
  );

  // Act
  final updated = await harness.trackingBloc.replace(t1.uuid, devices: []);

  // Assert
  expectThrough(harness.trackingBloc, emits(isA<TrackingUpdated>()), close: false);
  expect(updated.sources.isEmpty, isTrue, reason: "SHOULD be empty");
  expect(updated.tracks.length, 1, reason: "SHOULD contain 1 track");
  expect(updated.tracks.first.status, TrackStatus.detached, reason: "SHOULD be DETACHED");
}

Future<Tracking> _shouldUpdateUnitTrackingWhenPersonnelAdded(
  BlocTestHarness harness, {
  @required String puuid,
}) async {
  final uuuid = Uuid().v4();

  final ut1 = await _shouldUpdateTrackingWhenDeviceAdded<Unit>(
    harness,
    count: 1,
    reuse: false,
    act: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create(
      uuid: uuuid,
      status: UnitStatus.Mobilized,
    )),
  );
  expect(ut1.tracks.length, 1);

  final pt1 = await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
    harness,
    count: 2,
    reuse: true,
    act: (ouuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
      uuid: puuid,
      status: PersonnelStatus.Mobilized,
    )),
  );
  final personnel = harness.personnelBloc[puuid];
  expect(pt1.tracks.length, 1);

  // Act
  final updated = await harness.trackingBloc.attach(
    ut1.uuid,
    personnels: [personnel],
  );

  // Assert
  expectThrough(
    harness.trackingBloc,
    emits(isA<TrackingUpdated>()),
    close: false,
  );
  expect(updated.sources.length, 2, reason: "SHOULD contain 2 sources");
  expect(
    updated.sources.map((s) => s.uuid),
    [...ut1.sources.map((s) => s.uuid), personnel.uuid],
    reason: "SHOULD contain $personnel",
  );
  expect(updated.tracks.length, 2, reason: "SHOULD contain 2 track(s)");
  expect(updated.tracks[0].positions.length, 1, reason: "SHOULD contain 1 position");
  expect(
    updated.tracks[0].positions,
    contains(ut1.tracks.first.positions.first),
    reason: "SHOULD contain position ${ut1.tracks.first}",
  );
  expect(updated.tracks[1].positions.length, 1, reason: "SHOULD contain 1 position");
  expect(
    updated.tracks[1].positions,
    contains(pt1.position),
    reason: "SHOULD contain position ${pt1.position}",
  );

  return updated;
}

Future _shouldUpdateUnitTrackingWhenPersonnelRemoved(
  BlocTestHarness harness, {
  @required String puuid,
}) async {
  // Arrange
  final ut1 = await _shouldUpdateUnitTrackingWhenPersonnelAdded(
    harness,
    puuid: puuid,
  );
  expect(ut1.tracks.length, 2, reason: "SHOULD contain 2 track(s)");
  final personnel = harness.personnelBloc.repo[puuid];

  // Act
  final updated = await harness.trackingBloc.detach(
    ut1.uuid,
    personnels: [personnel],
  );

  // Assert
  expectThrough(harness.trackingBloc, emits(isA<TrackingUpdated>()));
  expect(updated.sources.length, 1, reason: "SHOULD contain 1 source(s)");
  expect(
    updated.sources.map((s) => s.uuid),
    [...ut1.sources.map((s) => s.uuid).where((suuid) => suuid != personnel.uuid)],
    reason: "SHOULD NOT contain detached personnel",
  );
  expect(updated.tracks.length, 2, reason: "SHOULD contain 2 track(s)");
}

Future<Tracking> _shouldUpdateTrackingWhenDeviceAdded<T extends Trackable>(
  BlocTestHarness harness, {
  @required Future<T> Function(String ouuid) act,
  bool reuse = false,
  int count = 1,
}) async {
  final automatic = await _shouldCreateTrackingAutomatically<T>(
    harness,
    act: act,
    reuse: reuse,
    count: count,
  );
  var device = DeviceBuilder.create(
    position: Position.fromPoint(
      toPoint(Defaults.origo),
      source: PositionSource.device,
    ),
    status: DeviceStatus.Available,
  );
  if (harness.isOnline) {
    harness.deviceService.put(
      harness.operationsBloc.selected.uuid,
      device,
    );
    await harness.deviceBloc.load();
  } else {
    device = await harness.deviceBloc.create(device);
  }
  expect(harness.deviceBloc.repo.length, count, reason: "SHOULD contain $count device(s)");

  // Act
  final updated = await harness.trackingBloc.attach(automatic.value.uuid, devices: [device]);

  // Assert
  expectThrough(harness.trackingBloc, emits(isA<TrackingUpdated>()), close: false);
  expect(
    updated.sources.map((source) => source.uuid),
    contains(device.uuid),
    reason: "SHOULD contain ${device.uuid}",
  );
  expect(updated.tracks.length, 1, reason: "SHOULD contain 1 track");
  expect(updated.tracks.first.status, TrackStatus.attached, reason: "SHOULD be ATTACHED");
  expect(updated.tracks.first.positions.length, 1, reason: "SHOULD contain 1 position");
  expect(updated.tracks.first.positions, contains(device.position), reason: "SHOULD contain 1 position");
  expect(
    updated.position?.geometry,
    equals(device.position.geometry),
    reason: "SHOULD BE ${device.position.geometry}",
  );

  return updated;
}

Future<T> _shouldCloseTrackingAutomatically<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) arrange,
  AsyncValueSetter<T> act,
}) async {
  T trackable;
  final state = await _shouldCreateTrackingAutomatically<T>(
    harness,
    act: (ouuid) async {
      trackable = await arrange(ouuid);
      return trackable;
    },
  );
  final tuuid = state.value.uuid;

  // Act LOCALLY
  await act(trackable);

  // Assert local state
  await _assertTrackingState<TrackingUpdated>(
    harness,
    tuuid,
    // When offline status will not change to updated
    harness.isOnline ? StorageStatus.updated : StorageStatus.created,
    remote: false,
  );

  if (harness.isOnline) {
    // Act - Simulate backend
    final tracking = harness.trackingBloc.repo[tuuid];
    await _putRemoteAndNotify(harness, tracking, TrackingMessageType.updated);

    // Assert REMOTELY
    await _assertTrackingState(
      harness,
      tuuid,
      StorageStatus.updated,
      remote: true,
    );
  }

  return trackable;
}

Future _shouldReopenClosedPersonnelTrackingAutomatically(BlocTestHarness harness, PersonnelStatus status) async {
  // Arrange
  final personnel = await _shouldCloseTrackingAutomatically<Personnel>(
    harness,
    arrange: (ouuid) async => await harness.personnelBloc.create(
      PersonnelBuilder.create(),
    ),
    act: (personnel) async {
      await harness.personnelBloc.update(
        personnel.copyWith(status: PersonnelStatus.Retired),
      );
      await expectThroughLater(
        harness.personnelBloc,
        emits(isA<PersonnelUpdated>()),
        close: false,
      );
    },
  );

  // Act and assert
  await _assertReopensClosedTrackingAutomatically<Personnel>(
    harness,
    status: TrackingStatus.created,
    act: () async {
      final next = await harness.personnelBloc.update(
        personnel.copyWith(status: status),
      );
      await expectThroughLater(
        harness.personnelBloc,
        emits(isA<PersonnelUpdated>()),
        close: false,
      );
      return next;
    },
  );
}

Future _shouldReopenClosedUnitTrackingAutomatically(
  BlocTestHarness harness,
  UnitStatus status,
) async {
  // Arrange
  final unit = await _shouldCloseTrackingAutomatically<Unit>(
    harness,
    arrange: (ouuid) async => await harness.unitBloc.create(UnitBuilder.create()),
    act: (personnel) async {
      await harness.unitBloc.update(
        personnel.copyWith(status: UnitStatus.Retired),
      );
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitUpdated>()),
        close: false,
      );
    },
  );

  // Act and assert
  await _assertReopensClosedTrackingAutomatically<Unit>(
    harness,
    status: TrackingStatus.created,
    act: () async {
      final next = await harness.unitBloc.update(
        unit.copyWith(status: status),
      );
      await expectThroughLater(
        harness.unitBloc,
        emits(isA<UnitUpdated>()),
        close: false,
      );
      return next;
    },
  );
}

Future<StorageState<Tracking>> _shouldCreateTrackingAutomatically<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String ouuid) act,
  int count = 1,
  bool reuse = false,
}) async {
  final operation = reuse ? harness.operationsBloc.selected : await _prepare(harness);

  // Act LOCALLY
  final trackable = await act(operation.uuid);
  final tuuid = trackable.tracking.uuid;

  // Assert locally CREATED
  final state = await _assertTrackingState<TrackingCreated>(
    harness,
    tuuid,
    StorageStatus.created,
    count: count,
    remote: false,
  );

  if (harness.isOnline) {
    // Act - Simulate backend
    final tracking = harness.trackingBloc.repo[tuuid];
    await _putRemoteAndNotify(harness, tracking, TrackingMessageType.created);

    // Assert
    return _assertTrackingState<TrackingCreated>(
      harness,
      tuuid,
      StorageStatus.created,
      count: count,
      remote: harness.isOnline,
    );
  }
  // Local state
  return state;
}

Future _shouldLoadTrackings(BlocTestHarness harness) async {
  Operation operation = await _prepare(harness);
  final tracking1 = harness.trackingService.add(operation.uuid);
  final tracking2 = harness.trackingService.add(operation.uuid);

  // Act
  List<Tracking> trackings = await harness.trackingBloc.load();

  // Assert
  if (harness.isOffline) {
    expect(trackings.length, 0, reason: "SHOULD contain 0 trackings");
    expect(
      harness.trackingBloc.repo.containsKey(tracking1.uuid),
      isFalse,
      reason: "SHOULD NOT contain tracking ${tracking1.uuid}",
    );
    expect(
      harness.trackingBloc.repo.containsKey(tracking2.uuid),
      isFalse,
      reason: "SHOULD NOT contain tracking ${tracking2.uuid}",
    );
  } else {
    expect(trackings.length, 2, reason: "SHOULD contain two trackings");
    expect(
      harness.trackingBloc.repo.containsKey(tracking1.uuid),
      isTrue,
      reason: "SHOULD contain tracking ${tracking1.uuid}",
    );
    expect(
      harness.trackingBloc.repo.containsKey(tracking2.uuid),
      isTrue,
      reason: "SHOULD contain tracking ${tracking2.uuid}",
    );
  }
  expectThrough(harness.trackingBloc, emits(isA<TrackingsLoaded>()));
}

Future _assertReopensClosedTrackingAutomatically<T extends Trackable>(
  BlocTestHarness harness, {
  @required TrackingStatus status,
  @required AsyncValueGetter<T> act,
}) async {
  // Act LOCALLY
  final trackable = await act();
  final tuuid = trackable.tracking.uuid;

  // Assert local state
  await _assertTrackingState<TrackingUpdated>(
    harness,
    tuuid,
    // When offline status will not change to updated
    harness.isOnline ? StorageStatus.updated : StorageStatus.created,
    remote: false,
  );

  if (harness.isOnline) {
    // Act - Simulate backend
    final tracking = harness.trackingBloc.repo[tuuid];
    await _putRemoteAndNotify(harness, tracking, TrackingMessageType.updated);

    // Assert REMOTELY
    await _assertTrackingState(
      harness,
      tuuid,
      StorageStatus.updated,
      remote: true,
    );
  }

  return trackable;
}

Future<StorageState<Tracking>> _assertTrackingState<T extends TrackingState>(
  BlocTestHarness harness,
  String tuuid,
  StorageStatus status, {
  @required bool remote,
  int count = 1,
}) async {
  await expectThroughLater(
    harness.trackingBloc,
    emitsInAnyOrder([isA<T>()]),
    close: false,
  );
  expect(harness.trackingBloc.repo.length, count, reason: "SHOULD contain $count tracking(s)");
  final state = harness.trackingBloc.repo.states[tuuid];
  expectStorageStatus(
    state,
    status,
    remote: remote,
  );
  expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");
  return state;
}

Future _putRemoteAndNotify(BlocTestHarness harness, Tracking tracking, TrackingMessageType type) async {
  harness.trackingService.put(harness.trackingBloc.ouuid, tracking);
  await _notify(harness, TrackingMessage(tracking.uuid, type, tracking.toJson()));
}

Future _notify(BlocTestHarness harness, TrackingMessage message) async {
  final messages = <TrackingMessage>[];
  final subscription = harness.trackingService.messages.listen(
    messages.add,
  );
  harness.trackingService.controller.add(message);
  await Future.delayed(Duration(milliseconds: 1));
  expect(messages, [isA<TrackingMessage>()]);
  await subscription.cancel();
}

Future _testShouldUnloadWhenOperationIsUnloaded(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, operation, tracking);

  // Act
  await harness.operationsBloc.unload();

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future<Tracking> _ensurePersonnelWithTracking(BlocTestHarness harness, Operation operation, Tracking tracking) async {
  harness.trackingService.put(operation.uuid, tracking);
  await harness.trackingBloc.load();
  expect(
    harness.trackingBloc.repo.length,
    harness.isOnline ? 1 : 0,
    reason: "SHOULD contain ${harness.isOnline ? 1 : 0} tracking",
  );
  if (harness.isOffline) {
    // Create any tracking for any trackable
    await harness.personnelBloc.create(PersonnelBuilder.create(tuuid: tracking.uuid));
    await expectThroughLater(
      harness.trackingBloc,
      emits(isA<TrackingCreated>()),
      close: false,
    );
    expect(
      harness.trackingBloc.repo.length,
      1,
      reason: "SHOULD contain 1 tracking",
    );
  }
  expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain 1 tracking");
  expect(harness.trackingBloc.ouuid, isNotNull, reason: "SHOULD NOT be null");
  expect(harness.trackingBloc.repo[tracking.uuid], isNotNull, reason: "SHOULD NOT be null");
  return harness.trackingBloc.repo[tracking.uuid];
}

Future _testShouldUnloadWhenOperationIsResolved(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, operation, tracking);

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(status: OperationStatus.completed),
  );
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsCancelled(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, operation, tracking);

  // Act
  await harness.operationsBloc.update(
    operation.copyWith(
      status: OperationStatus.completed,
      resolution: OperationResolution.cancelled,
    ),
  );
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldUnloadWhenOperationIsDeleted(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, operation, tracking);

  // Act
  await harness.operationsBloc.delete(operation.uuid);
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  await expectThroughLater(
    harness.unitBloc,
    emits(isA<UnitsUnloaded>()),
    close: false,
  );

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.ouuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldReloadWhenOperationIsSwitched(BlocTestHarness harness) async {
  final operation = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  harness.trackingService.put(operation.uuid, tracking);
  await harness.trackingBloc.load();
  expect(
    harness.trackingBloc.repo.length,
    harness.isOnline ? 1 : 0,
    reason: "SHOULD contain ${harness.isOnline ? 1 : 0} tracking",
  );

  // Act
  final incident = IncidentBuilder.create();
  final operation2 = await harness.operationsBloc.create(
    OperationBuilder.create(harness.userBloc.userId, iuuid: incident.uuid),
    incident: incident,
    selected: true,
  );

  // Assert
  await expectThroughInOrderLater(
    harness.trackingBloc,
    [isA<TrackingsUnloaded>(), isA<TrackingsLoaded>()],
  );
  expect(harness.trackingBloc.ouuid, operation2.uuid, reason: "SHOULD change to ${operation2.uuid}");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
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

  // Prepare TrackingBloc
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingsLoaded>()), close: false);
  expect(harness.trackingBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.trackingBloc.ouuid, operation.uuid, reason: "SHOULD depend on operation ${operation.uuid}");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelsLoaded>()), close: false);
  expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.personnelBloc.ouuid, operation.uuid, reason: "SHOULD depend on operation ${operation.uuid}");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.unitBloc, emits(isA<UnitsLoaded>()), close: false);
  expect(harness.unitBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.unitBloc.ouuid, operation.uuid, reason: "SHOULD depend on operation ${operation.uuid}");

  return operation;
}
