// @dart=2.11

import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/core/utils/data.dart';

class UnitBuilder {
  static Unit create({
    String uuid,
    String ouuid,
    String tuuid,
    String userId,
    int number = 1,
    List<String> personnels,
    UnitType type = UnitType.team,
    UnitStatus status = UnitStatus.mobilized,
  }) {
    return UnitModel.fromJson(
      createAsJson(
        ouuid: ouuid,
        uuid: uuid ?? Uuid().v4(),
        type: type ?? UnitType.team,
        number: number ?? 1,
        status: status ?? UnitStatus.mobilized,
        tuuid: tuuid,
        personnels: (personnels ?? []).toList(),
      ),
    );
  }

  static createAsJson({
    @required String ouuid,
    String uuid,
    UnitType type,
    int number,
    UnitStatus status,
    List<String> personnels,
    String tuuid,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"number": $number,'
        '"type": "${enumName(type)}",'
        '"callsign": "${translateUnitType(type)} $number",'
        '"status": "${enumName(status)}",'
        '"personnels": [${personnels != null ? '"${personnels.join('","')}"' : ''}],'
        '"operation": {"uuid": "${ouuid ?? Uuid().v4()}", "type": "Operation"},'
        '"tracking": {"uuid": "${tuuid ?? Uuid().v4()}", "type": "Unit"}'
        '}');
  }
}

class UnitServiceMock extends Mock implements UnitService {
  final Map<String, Map<String, StorageState<Unit>>> unitsRepo = {};

  Unit add(
    String ouuid, {
    String uuid,
    String tracking,
    UnitType type = UnitType.team,
    UnitStatus status = UnitStatus.mobilized,
  }) {
    final unit = UnitBuilder.create(
      uuid: uuid,
      type: type,
      ouuid: ouuid,
      status: status,
      tuuid: tracking,
    );
    final state = StorageState.created(
      unit,
      StateVersion.first,
      isRemote: true,
    );

    if (unitsRepo.containsKey(ouuid)) {
      unitsRepo[ouuid].putIfAbsent(unit.uuid, () => state);
    } else {
      unitsRepo[ouuid] = {unit.uuid: state};
    }
    return unit;
  }

  List<StorageState<Unit>> remove(String uuid) {
    final ouuids = unitsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return ouuids
        .map((ouuid) => unitsRepo[ouuid].remove(uuid))
        .where(
          (unit) => unit != null,
        )
        .toList();
  }

  static UnitService build(final int count, {List<String> ouuids = const []}) {
    final UnitServiceMock mock = UnitServiceMock();
    final unitsRepo = mock.unitsRepo;
    final StreamController<UnitMessage> controller = StreamController.broadcast();

    // Only generate units for automatically generated ouuids
    ouuids.forEach((ouuid) {
      if (ouuid.startsWith('a:')) {
        final units = unitsRepo.putIfAbsent(ouuid, () => {});
        units.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$ouuid:u:$i",
              StorageState.created(
                UnitModel.fromJson(
                  UnitBuilder.createAsJson(
                    ouuid: ouuid,
                    uuid: "$ouuid:u:$i",
                    type: UnitType.team,
                    number: i,
                    status: UnitStatus.mobilized,
                    tuuid: "$ouuid:t:u:$i",
                  ),
                ),
                StateVersion.first,
                isRemote: true,
              ),
            ),
        ]);
      }
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.getListFromId(any)).thenAnswer((_) async {
      final String ouuid = _.positionalArguments[0];
      var units = unitsRepo[ouuid];
      if (units == null) {
        units = unitsRepo.putIfAbsent(ouuid, () => {});
      }
      return ServiceResponse.ok(
        body: units.values.toList(growable: false),
      );
    });

    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Unit>;
      final ouuid = state.value.operation.uuid;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final unit = state.value;
      final unitRepo = unitsRepo.putIfAbsent(ouuid, () => {});
      final String puuid = unit.uuid;
      unitRepo[puuid] = state.remote(
        unit.copyWith(
          operation: state.value.operation,
        ),
        version: state.version,
      );
      return ServiceResponse.ok(
        body: unitRepo[puuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Unit>;
      final unit = next.value;
      final puuid = unit.uuid;
      final ouuid = unit.operation.uuid;
      final unitRepo = unitsRepo.putIfAbsent(ouuid, () => {});
      if (unitRepo.containsKey(puuid)) {
        final state = unitRepo[puuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        unitRepo[puuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: unitRepo[puuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Unit not found: $puuid",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Unit>;
      final unit = state.value;
      final puuid = unit.uuid;
      final ouuid = unit.operation.uuid;
      final unitRepo = unitsRepo.putIfAbsent(ouuid, () => {});
      if (unitRepo.containsKey(puuid)) {
        return ServiceResponse.ok(
          body: unitRepo.remove(puuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Unit not found: $puuid",
      );
    });
    return mock;
  }
}
