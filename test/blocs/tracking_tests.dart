import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/personnels.dart';
import 'package:SarSys/mock/trackings.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/repositories/tracking_repository.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc()
    ..withTrackingBloc()
    ..withPersonnelBloc()
    ..withDeviceBloc()
    ..withUnitBloc()
    ..withTrackingBloc()
    ..install();

  test(
    'TrackingBloc should be EMPTY and UNSET',
    () async {
      expect(harness.trackingBloc.iuuid, isNull, reason: "SHOULD BE unset");
      expect(harness.trackingBloc.trackings.length, 0, reason: "SHOULD BE empty");
      expect(harness.trackingBloc.initialState, isA<TrackingsEmpty>(), reason: "Unexpected tracking state");
      await expectExactlyLater(harness.trackingBloc, [isA<TrackingsEmpty>()]);
    },
  );

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
        act: (iuuid) async => await harness.unitBloc.create(unit),
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
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
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
      );
    });

    test('SHOULD update unit tracking when device is removed', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create(
          status: UnitStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update unit tracking when personnel is added', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelAdded(harness);
    });

    test('SHOULD update unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD replace unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD attach to unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD delete from unit tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD update personnel tracking when device is added', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD replace personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD attach to personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking directly', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD delete from personnel tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
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
        arrange: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
        act: (unit) async {
          await harness.unitBloc.update(
            unit.cloneWith(status: UnitStatus.Retired),
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
        arrange: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
        act: (personnel) async {
          await harness.personnelBloc.update(
            personnel.cloneWith(status: PersonnelStatus.Retired),
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
        act: (iuuid) async => await harness.unitBloc.create(unit),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      await _shouldDeleteTrackingAutomatically<Unit>(
        harness,
        tuuid,
        act: (tuuid) => harness.unitBloc.delete(unit),
      );
    });

    test('SHOULD delete personnel tracking automatically', () async {
      // Arrange
      harness.connectivity.cellular();
      final personnel = PersonnelBuilder.create();
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(personnel),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      await _shouldDeleteTrackingAutomatically<Personnel>(
        harness,
        tuuid,
        act: (tuuid) => harness.personnelBloc.delete(personnel),
      );
    });

    test('SHOULD update tracking on remote change', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);

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
      expect(harness.trackingBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");

      // Act REMOTELY
      final tracking = harness.trackingBloc.repo[tuuid];
      await _addMessage(harness, TrackingMessage.created(tracking));

      // Assert PUSHED
      await expectThroughLater(
        harness.trackingBloc,
        emitsInAnyOrder([isA<TrackingCreated>()]),
        close: false,
      );
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expect(
        harness.trackingBloc.repo.states[tuuid].status,
        equals(StorageStatus.pushed),
        reason: "SHOULD HAVE status PUSHED",
      );
      expect(harness.trackingBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.cellular();
      final incident = await _prepare(harness);
      harness.trackingService.add(incident.uuid);
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
      final incident = await _prepare(harness);
      final tracking = harness.trackingService.add(incident.uuid);
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

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.cellular();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
    });
  });

  group('WHEN TrackingBloc is OFFLINE', () {
    test('SHOULD NOT load trackings', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldLoadTrackings(harness);
    });

    test('SHOULD create unit tracking automatically', () async {
      // Arrange
      harness.connectivity.offline();
      final unit = UnitBuilder.create(personnels: [
        PersonnelBuilder.create(),
        PersonnelBuilder.create(),
      ]);

      // Act and assert
      final state = await _shouldCreateTrackingAutomatically<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(unit),
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
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
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create(status: UnitStatus.Mobilized)),
      );
    });

    test('SHOULD update unit tracking when device is removed', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceRemoved<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create(
          status: UnitStatus.Mobilized,
        )),
      );
    });

    test('SHOULD update unit tracking when personnel is added', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateUnitTrackingWhenPersonnelAdded(harness);
    });

    test('SHOULD update unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD replace unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD attach to unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD detach from unit tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD delete from unit tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Unit>(
        harness,
        act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
      );
    });

    test('SHOULD update personnel tracking when device is added', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
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
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD replace personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldReplaceTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD attach to personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldAttachToTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking directly', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingDirectly<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD detach from personnel tracking when device is unavailable', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDetachFromTrackingWhenDeviceUnavailable<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
      );
    });

    test('SHOULD delete from personnel tracking when device is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and assert
      await _shouldDeleteFromTrackingWhenDeviceDeleted<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
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
        arrange: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
        act: (unit) async {
          await harness.unitBloc.update(
            unit.cloneWith(status: UnitStatus.Retired),
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
        arrange: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create()),
        act: (personnel) async {
          await harness.personnelBloc.update(
            personnel.cloneWith(status: PersonnelStatus.Retired),
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
        act: (iuuid) async => await harness.unitBloc.create(unit),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      harness.connectivity.offline();
      await _shouldDeleteTrackingAutomatically<Unit>(
        harness,
        tuuid,
        act: (tuuid) => harness.unitBloc.delete(unit),
      );
    });

    test('SHOULD delete personnel tracking automatically locally', () async {
      // Arrange
      harness.connectivity.offline();
      final personnel = PersonnelBuilder.create();
      final state = await _shouldCreateTrackingAutomatically<Personnel>(
        harness,
        act: (iuuid) async => await harness.personnelBloc.create(personnel),
      );
      final tuuid = state.value.uuid;

      // Act and Assert
      await _shouldDeleteTrackingAutomatically<Personnel>(
        harness,
        tuuid,
        act: (tuuid) => harness.personnelBloc.delete(personnel),
      );
    });

    test('SHOULD update tracking on remote change', () async {
      // Arrange
      harness.connectivity.offline();
      final incident = await _prepare(harness);

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
      expect(harness.trackingBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");

      // Act REMOTELY
      final tracking = harness.trackingBloc.repo[tuuid];
      await _addMessage(harness, TrackingMessage.created(tracking));

      // Assert PUSHED
      await expectThroughLater(
        harness.trackingBloc,
        emitsInAnyOrder([isA<TrackingCreated>()]),
        close: false,
      );
      expect(harness.trackingBloc.repo.length, 1, reason: "SHOULD contain one tracking");
      expect(
        harness.trackingBloc.repo.states[tuuid].status,
        equals(StorageStatus.pushed),
        reason: "SHOULD HAVE status PUSHED",
      );
      expect(harness.trackingBloc.iuuid, incident.uuid, reason: "SHOULD depend on ${incident.uuid}");
      expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");
    });

    test('SHOULD BE empty after unload', () async {
      // Arrange
      harness.connectivity.offline();
      final incident = await _prepare(harness);
      final tracking = TrackingBuilder.create();
      await _ensurePersonnelWithTracking(harness, incident, tracking);

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
      final incident = await _prepare(harness);
      final tracking = TrackingBuilder.create();
      await _ensurePersonnelWithTracking(harness, incident, tracking);

      // Act
      await harness.trackingBloc.unload();
      await harness.trackingBloc.load();

      // Assert
      expect(harness.trackingBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
      expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD contain 0 trackings");
      expect(
        harness.trackingBloc.repo.containsKey(tracking.uuid),
        isFalse,
        reason: "SHOULD not contain tracking ${tracking.uuid}",
      );
      expectThroughInOrder(harness.trackingBloc, [isA<TrackingsUnloaded>(), isA<TrackingsLoaded>()]);
    });

    test('SHOULD reload when incident is switched', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldReloadWhenIncidentIsSwitched(harness);
    });

    test('SHOULD unload when incident is deleted', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsDeleted(harness);
    });

    test('SHOULD unload when incident is cancelled', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsCancelled(harness);
    });

    test('SHOULD unload when incident is resolved', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsResolved(harness);
    });

    test('SHOULD unload when incidents are unloaded', () async {
      // Arrange
      harness.connectivity.offline();

      // Act and Assert
      await _testShouldUnloadWhenIncidentIsUnloaded(harness);
    });
  });
}

Future<Tracking> _shouldUpdateTrackingDirectly<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String iuuid) act,
}) async {
  final state = await _shouldCreateTrackingAutomatically<T>(
    harness,
    act: act,
  );
  final t1 = state.value;
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);

  // Act
  final t2 = await harness.trackingBloc.update(t1, position: p2, status: TrackingStatus.tracking);

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
  Future<T> Function(String iuuid) act,
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
  final t2 = await harness.trackingBloc.replace(t1, position: p2, devices: [d2]);

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
  Future<T> Function(String iuuid) act,
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
  final t2 = await harness.trackingBloc.attach(t1, position: p2, devices: [d2]);

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
  Future<T> Function(String iuuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final d1 = harness.deviceBloc.repo[t1.sources.last.uuid];
  final p2 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);

  // Act
  final t2 = await harness.trackingBloc.detach(t1, position: p2, devices: [d1]);

  // Assert
  expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.status, equals(TrackingStatus.tracking), reason: "SHOULD be status tracking");
  expect(t2.history.length, 3, reason: "SHOULD be length 3");
  expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be position p2");
  expect(t2.history.last.source, equals(PositionSource.manual), reason: "SHOULD be manual");
  expect(t2.sources.length, 1, reason: "SHOULD be length 2");
  expect(t2.sources.map((e) => e.uuid), isNot(contains(d1.uuid)), reason: "SHOULD NOT contain uuid of d1");
  expect(t2.tracks.length, 1, reason: "SHOULD be length 1");
  expect(t2.tracks.map((e) => e.source.uuid), isNot(contains(d1.uuid)), reason: "SHOULD NOT contain uuid of d1");

  return t2;
}

Future<Tracking> _shouldDetachFromTrackingWhenDeviceUnavailable<T extends Trackable>(
  BlocTestHarness harness, {
  Future<T> Function(String iuuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final p3 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available, position: p3));
  final t2 = await harness.trackingBloc.attach(t1, devices: [d3]);
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
  Future<T> Function(String iuuid) act,
}) async {
  final t1 = await _shouldAttachToTrackingDirectly<T>(
    harness,
    act: act,
  );
  final p3 = Position.now(lat: 1, lon: 1, source: PositionSource.manual);
  final d3 = await harness.deviceBloc.create(DeviceBuilder.create(status: DeviceStatus.Available, position: p3));
  final t2 = await harness.trackingBloc.attach(t1, devices: [d3]);
  expect(t2.history.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.length, 3, reason: "SHOULD be length 3");
  expect(t2.sources.map((e) => e.uuid), contains(d3.uuid), reason: "SHOULD NOT contain uuid of d3");
  expect(t2.tracks.length, 3, reason: "SHOULD be length 3");
  expect(t2.tracks.map((e) => e.source.uuid), contains(d3.uuid), reason: "SHOULD NOT contain uuid of d3");

  // Act
  await harness.deviceBloc.delete(d3);

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
    reason: "SHOULD contain unique ${typeOf<T>()}s",
  );
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingCreated>()), close: false);
  final first = harness.trackingBloc.repo[trackables.first.tracking.uuid];
  final d1 = await harness.deviceBloc.create(DeviceBuilder.create());
  final s1 = PositionableSource.from(d1, position: p1);
  await harness.trackingBloc.attach(TrackingUtils.attachAll(first, [s1]));
  final last = harness.trackingBloc.repo[trackables.last.tracking.uuid];
  final withDuplicates = TrackingUtils.attachAll(last, [s1]);

  // Assert
  expect(
    () async => await harness.trackingBloc.attach(withDuplicates),
    throwsA(
      isA<TrackingBlocError>().having((error) => error.data, 'data', isA<TrackingSourceAlreadyTrackedException>()),
    ),
    reason: "SHOULD throw TrackingError",
  );
}

Future _shouldDeleteTrackingAutomatically<T extends Trackable>(
  BlocTestHarness harness,
  String tuuid, {
  Future<T> Function(String iuuid) act,
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
  @required Future<T> Function(String iuuid) act,
}) async {
  final tracking = await _shouldUpdateTrackingWhenDeviceAdded<T>(
    harness,
    act: act,
  );

  // Act
  final updated = await harness.trackingBloc.replace(tracking, devices: []);

  // Assert
  expectThrough(harness.trackingBloc, emits(isA<TrackingUpdated>()), close: false);
  expect(updated.sources.isEmpty, isTrue, reason: "SHOULD be empty");
  expect(updated.tracks.length, 1, reason: "SHOULD contain 1 track");
  expect(updated.tracks.first.status, TrackStatus.detached, reason: "SHOULD be DETACHED");
}

Future _shouldUpdateUnitTrackingWhenPersonnelAdded(BlocTestHarness harness) async {
  final uuuid = Uuid().v4();
  final puuid = Uuid().v4();

  final unitTracking = await _shouldUpdateTrackingWhenDeviceAdded<Unit>(
    harness,
    count: 1,
    reuse: false,
    act: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create(
      uuid: uuuid,
      status: UnitStatus.Mobilized,
    )),
  );
  expect(unitTracking.tracks.length, 1);

  final personnelTracking = await _shouldUpdateTrackingWhenDeviceAdded<Personnel>(
    harness,
    count: 2,
    reuse: true,
    act: (iuuid) async => await harness.personnelBloc.create(PersonnelBuilder.create(
      uuid: puuid,
      status: PersonnelStatus.Mobilized,
    )),
  );
  final personnel = harness.personnelBloc[puuid];
  expect(personnelTracking.tracks.length, 1);

  // Act
  final updated = await harness.trackingBloc.attach(
    unitTracking,
    personnels: [personnel],
  );

  // Assert
  expectThrough(harness.trackingBloc, emits(isA<TrackingUpdated>()));
  expect(updated.sources.length, 2, reason: "SHOULD contain 2 sources");
  expect(
    updated.sources.map((s) => s.uuid),
    [
      ...unitTracking.sources.map((s) => s.uuid),
      personnel.uuid,
    ],
    reason: "SHOULD contain $personnel",
  );
  expect(updated.tracks.length, 2, reason: "SHOULD contain 2 track(s)");
  expect(updated.tracks[0].positions.length, 1, reason: "SHOULD contain 1 position");
  expect(
    updated.tracks[0].positions,
    contains(unitTracking.tracks.first.positions.first),
    reason: "SHOULD contain position ${unitTracking.tracks.first}",
  );
  expect(updated.tracks[1].positions.length, 1, reason: "SHOULD contain 1 position");
  expect(
    updated.tracks[1].positions,
    contains(personnelTracking.position),
    reason: "SHOULD contain position ${personnelTracking.position}",
  );
}

Future<Tracking> _shouldUpdateTrackingWhenDeviceAdded<T extends Trackable>(
  BlocTestHarness harness, {
  @required Future<T> Function(String iuuid) act,
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
      harness.incidentBloc.selected.uuid,
      device,
    );
    await harness.deviceBloc.load();
  } else {
    device = await harness.deviceBloc.create(device);
  }
  expect(harness.deviceBloc.repo.length, count, reason: "SHOULD contain $count device(s)");

  // Act
  final updated = await harness.trackingBloc.attach(automatic.value, devices: [device]);

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
  Future<T> Function(String iuuid) arrange,
  AsyncValueSetter<T> act,
  bool offline = false,
}) async {
  T trackable;
  final state = await _shouldCreateTrackingAutomatically<T>(
    harness,
    act: (iuuid) async {
      trackable = await arrange(iuuid);
      return trackable;
    },
  );
  final tuuid = state.value.uuid;

  // Act LOCALLY
  await act(trackable);

  // Assert LOCALLY
  if (offline) {
    await _assertTrackingState(harness, tuuid, StorageStatus.changed);
    // Act REMOTELY
    final tracking = harness.trackingBloc.repo[tuuid];
    await _addAndNotify(harness, tracking, TrackingMessageType.updated);
  }

  // Assert REMOTELY
  await _assertTrackingState(harness, tuuid, StorageStatus.pushed);

  return trackable;
}

Future _shouldReopenClosedPersonnelTrackingAutomatically(BlocTestHarness harness, PersonnelStatus status) async {
  // Arrange
  final personnel = await _shouldCloseTrackingAutomatically<Personnel>(
    harness,
    arrange: (iuuid) async => await harness.personnelBloc.create(
      PersonnelBuilder.create(),
    ),
    act: (personnel) async {
      await harness.personnelBloc.update(
        personnel.cloneWith(status: PersonnelStatus.Retired),
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
        personnel.cloneWith(status: status),
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
    arrange: (iuuid) async => await harness.unitBloc.create(UnitBuilder.create()),
    act: (personnel) async {
      await harness.unitBloc.update(
        personnel.cloneWith(status: UnitStatus.Retired),
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
        unit.cloneWith(status: status),
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
  Future<T> Function(String iuuid) act,
  int count = 1,
  bool reuse = false,
}) async {
  final incident = reuse ? harness.incidentBloc.selected : await _prepare(harness);

  // Act LOCALLY
  final trackable = await act(incident.uuid);

  // Assert
  return await _assertCreatedTrackingAutomatically(trackable.tracking.uuid, harness, count: count);
}

Future _shouldLoadTrackings(BlocTestHarness harness) async {
  Incident incident = await _prepare(harness);
  final tracking1 = harness.trackingService.add(incident.uuid);
  final tracking2 = harness.trackingService.add(incident.uuid);

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

  // Assert REMOTELY
  final remote = await _assertTrackingState<TrackingUpdated>(harness, tuuid, StorageStatus.pushed);
  expect(remote.value.status, status, reason: "SHOULD BE ${enumName(status)}");
}

Future<StorageState<Tracking>> _assertCreatedTrackingAutomatically(
  String tuuid,
  BlocTestHarness harness, {
  int count = 1,
}) async {
  // Assert CREATED
  await _assertTrackingState<TrackingCreated>(
    harness,
    tuuid,
    StorageStatus.created,
    count: count,
  );

  // Act REMOTELY
  final tracking = harness.trackingBloc.repo[tuuid];
  await _addAndNotify(harness, tracking, TrackingMessageType.created);

  // Assert PUSHED
  return _assertTrackingState<TrackingCreated>(
    harness,
    tuuid,
    StorageStatus.pushed,
    count: count,
  );
}

Future<StorageState<Tracking>> _assertTrackingState<T extends TrackingState>(
  BlocTestHarness harness,
  String tuuid,
  StorageStatus type, {
  int count = 1,
}) async {
  await expectThroughLater(
    harness.trackingBloc,
    emitsInAnyOrder([isA<T>()]),
    close: false,
  );
  expect(harness.trackingBloc.repo.length, count, reason: "SHOULD contain $count tracking(s)");
  final state = harness.trackingBloc.repo.states[tuuid];
  expect(
    state.status,
    equals(type),
    reason: "SHOULD HAVE status ${enumName(type)}",
  );
  expect(harness.trackingBloc.repo.containsKey(tuuid), isTrue, reason: "SHOULD contain tracking $tuuid");
  return state;
}

Future _addAndNotify(BlocTestHarness harness, Tracking tracking, TrackingMessageType type) async {
  harness.trackingService.put(harness.trackingBloc.iuuid, tracking);
  await _addMessage(harness, TrackingMessage(tracking.uuid, type, tracking.toJson()));
}

Future _addMessage(BlocTestHarness harness, TrackingMessage message) async {
  final messages = <TrackingMessage>[];
  final subscription = harness.trackingService.messages.listen(
    messages.add,
  );
  harness.trackingService.controller.add(message);
  await Future.delayed(Duration(milliseconds: 1));
  expect(messages, [isA<TrackingMessage>()]);
  await subscription.cancel();
}

Future _testShouldUnloadWhenIncidentIsUnloaded(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, incident, tracking);

  // Act
  await harness.incidentBloc.unload();

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future<Tracking> _ensurePersonnelWithTracking(BlocTestHarness harness, Incident incident, Tracking tracking) async {
  harness.trackingService.put(incident.uuid, tracking);
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
  expect(harness.trackingBloc.iuuid, isNotNull, reason: "SHOULD NOT be null");
  expect(harness.trackingBloc.repo[tracking.uuid], isNotNull, reason: "SHOULD NOT be null");
  return harness.trackingBloc.repo[tracking.uuid];
}

Future _testShouldUnloadWhenIncidentIsResolved(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, incident, tracking);

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Resolved),
  );

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsCancelled(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, incident, tracking);

  // Act
  await harness.incidentBloc.update(
    incident.cloneWith(status: IncidentStatus.Cancelled),
  );

  // Assert
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldUnloadWhenIncidentIsDeleted(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  await _ensurePersonnelWithTracking(harness, incident, tracking);

  // Act
  await harness.incidentBloc.delete(incident.uuid);

  // Assert
  await expectThroughLater(
    harness.personnelBloc,
    emits(isA<PersonnelsUnloaded>()),
    close: false,
  );
  await expectThroughLater(
    harness.trackingBloc,
    emits(isA<TrackingsUnloaded>()),
    close: false,
  );
  expect(harness.trackingBloc.iuuid, isNull, reason: "SHOULD change to null");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
  );
}

Future _testShouldReloadWhenIncidentIsSwitched(BlocTestHarness harness) async {
  final incident = await _prepare(harness);
  final tracking = TrackingBuilder.create();
  harness.trackingService.put(incident.uuid, tracking);
  await harness.trackingBloc.load();
  expect(
    harness.trackingBloc.repo.length,
    harness.isOnline ? 1 : 0,
    reason: "SHOULD contain ${harness.isOnline ? 1 : 0} tracking",
  );

  // Act
  var incident2 = IncidentBuilder.create(harness.userBloc.userId);
  incident2 = await harness.incidentBloc.create(incident2, selected: true);

  // Assert
  await expectThroughInOrderLater(
    harness.trackingBloc,
    [isA<TrackingsUnloaded>(), isA<TrackingsLoaded>()],
  );
  expect(harness.trackingBloc.iuuid, incident2.uuid, reason: "SHOULD change to ${incident2.uuid}");
  expect(harness.trackingBloc.repo.length, 0, reason: "SHOULD BE empty");
  expect(
    harness.trackingBloc.repo.containsKey(tracking.uuid),
    isFalse,
    reason: "SHOULD NOT contain tracking ${tracking.uuid}",
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

  // Prepare TrackingBloc
  await expectThroughLater(harness.trackingBloc, emits(isA<TrackingsLoaded>()), close: false);
  expect(harness.trackingBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.trackingBloc.iuuid, incident.uuid, reason: "SHOULD depend on incident ${incident.uuid}");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.personnelBloc, emits(isA<PersonnelsLoaded>()), close: false);
  expect(harness.personnelBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.personnelBloc.iuuid, incident.uuid, reason: "SHOULD depend on incident ${incident.uuid}");

  // Prepare PersonnelBloc
  await expectThroughLater(harness.unitBloc, emits(isA<UnitsLoaded>()), close: false);
  expect(harness.unitBloc.isUnset, isFalse, reason: "SHOULD NOT be unset");
  expect(harness.unitBloc.iuuid, incident.uuid, reason: "SHOULD depend on incident ${incident.uuid}");

  return incident;
}
