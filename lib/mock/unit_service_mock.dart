import 'dart:convert';

import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/utils/data_utils.dart';

class UnitBuilder {
  static Unit create({
    String uuid,
    String userId,
    String tuuid,
    int number = 1,
    List<Personnel> personnels,
    UnitType type = UnitType.team,
    UnitStatus status = UnitStatus.mobilized,
  }) {
    return UnitModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        type: type ?? UnitType.team,
        number: number ?? 1,
        status: status ?? UnitStatus.mobilized,
        tuuid: tuuid,
        personnels: (personnels ?? []).map((p) => jsonEncode(p.toJson())).toList(),
      ),
    );
  }

  static createAsJson({
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
        '"personnels": [${personnels != null ? personnels.join(',') : ''}],'
        '"tracking": {"uuid": "${tuuid ?? Uuid().v4()}", "type": "Unit"}'
        '}');
  }
}

class UnitServiceMock extends Mock implements UnitService {
  final Map<String, Map<String, Unit>> unitsRepo = {};

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
      status: status,
      tuuid: tracking,
    );
    if (unitsRepo.containsKey(ouuid)) {
      unitsRepo[ouuid].putIfAbsent(unit.uuid, () => unit);
    } else {
      unitsRepo[ouuid] = {unit.uuid: unit};
    }
    return unit;
  }

  List<Unit> remove(String uuid) {
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

    // Only generate units for automatically generated ouuids
    ouuids.forEach((ouuid) {
      if (ouuid.startsWith('a:')) {
        final units = unitsRepo.putIfAbsent(ouuid, () => {});
        units.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$ouuid:u:$i",
              UnitModel.fromJson(
                UnitBuilder.createAsJson(
                  uuid: "$ouuid:u:$i",
                  type: UnitType.team,
                  number: i,
                  status: UnitStatus.mobilized,
                  tuuid: "$ouuid:t:u:$i",
                ),
              ),
            ),
        ]);
      }
    });

    when(mock.fetchAll(any)).thenAnswer((_) async {
      final String ouuid = _.positionalArguments[0];
      var units = unitsRepo[ouuid];
      if (units == null) {
        units = unitsRepo.putIfAbsent(ouuid, () => {});
      }
      return ServiceResponse.ok(
        body: units.values.toList(growable: false),
      );
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      final ouuid = _.positionalArguments[0];
      final Unit unit = _.positionalArguments[1];
      final units = unitsRepo.putIfAbsent(ouuid, () => {});
      units.putIfAbsent(unit.uuid, () => unit);
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      var units = unitsRepo.entries.firstWhere((entry) => entry.value.containsKey(unit.uuid), orElse: () => null);
      if (units != null) {
        units.value.update(unit.uuid, (_) => unit, ifAbsent: () => unit);
        return ServiceResponse.ok(
          body: units.value.update(unit.uuid, (_) => unit, ifAbsent: () => unit),
        );
      }
      return ServiceResponse.notFound(
        message: "Unit not found: ${unit.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final uuuid = _.positionalArguments[0] as String;
      var ouuid = unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(uuuid),
        orElse: () => null,
      );
      if (ouuid != null) {
        ouuid.value.remove(uuuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Unit not found: $uuuid",
      );
    });
    return mock;
  }
}
