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
    UnitType type = UnitType.Team,
    UnitStatus status = UnitStatus.Mobilized,
  }) {
    return UnitModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        type: type ?? UnitType.Team,
        number: number ?? 1,
        status: status ?? UnitStatus.Mobilized,
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
    String iuuid, {
    String uuid,
    String tracking,
    UnitType type = UnitType.Team,
    UnitStatus status = UnitStatus.Mobilized,
  }) {
    final unit = UnitBuilder.create(
      uuid: uuid,
      type: type,
      status: status,
      tuuid: tracking,
    );
    if (unitsRepo.containsKey(iuuid)) {
      unitsRepo[iuuid].putIfAbsent(unit.uuid, () => unit);
    } else {
      unitsRepo[iuuid] = {unit.uuid: unit};
    }
    return unit;
  }

  List<Unit> remove(String uuid) {
    final iuuids = unitsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((iuuid) => unitsRepo[iuuid].remove(uuid))
        .where(
          (unit) => unit != null,
        )
        .toList();
  }

  static UnitService build(final int count, {List<String> iuuids = const []}) {
    final UnitServiceMock mock = UnitServiceMock();
    final unitsRepo = mock.unitsRepo;

    // Only generate units for automatically generated iuuids
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        final units = unitsRepo.putIfAbsent(iuuid, () => {});
        units.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$iuuid:u:$i",
              UnitModel.fromJson(
                UnitBuilder.createAsJson(
                  uuid: "$iuuid:u:$i",
                  type: UnitType.Team,
                  number: i,
                  status: UnitStatus.Mobilized,
                  tuuid: "$iuuid:t:u:$i",
                ),
              ),
            ),
        ]);
      }
    });

    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var units = unitsRepo[iuuid];
      if (units == null) {
        units = unitsRepo.putIfAbsent(iuuid, () => {});
      }
      return ServiceResponse.ok(
        body: units.values.toList(growable: false),
      );
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      final iuuid = _.positionalArguments[0];
      final Unit unit = _.positionalArguments[1];
      final units = unitsRepo.putIfAbsent(iuuid, () => {});
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
      var iuuid = unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(uuuid),
        orElse: () => null,
      );
      if (iuuid != null) {
        iuuid.value.remove(uuuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Unit not found: $uuuid",
      );
    });
    return mock;
  }
}
