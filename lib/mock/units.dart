import 'dart:convert';

import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:mockito/mockito.dart';

class UnitBuilder {
  static createUnitAsJson(String id, UnitType type, int number, String tracking) {
    return json.decode('{'
        '"id": "$id",'
        '"number": $number,'
        '"type": "${enumName(type)}",'
        '"callsign": "${translateUnitType(type)} $number",'
        '"status": "${enumName(UnitStatus.Mobilized)}",'
        '"tracking": "$tracking"'
        '}');
  }
}

class UnitServiceMock extends Mock implements UnitService {
  static UnitService build(final int count) {
    final Map<String, Unit> units = {};
    final UnitServiceMock mock = UnitServiceMock();
    when(mock.fetch(any)).thenAnswer((id) async {
      if (units.isEmpty) {
        units.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
                "u$i",
                Unit.fromJson(
                  UnitBuilder.createUnitAsJson("u$i", UnitType.Team, i, "t$i"),
                )),
        ]);
      }
      return ServiceResponse.ok(body: units.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      final String id = "u${units.length + 1}";
      return ServiceResponse.ok(body: units.putIfAbsent(id, () => unit.cloneWith(id: id)));
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      if (units.containsKey(unit.id)) {
        units.update(unit.id, (_) => unit, ifAbsent: () => unit);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Unit ${unit.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      if (units.containsKey(unit.id)) {
        units.remove(unit.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Unit ${unit.id}");
    });
    return mock;
  }
}
