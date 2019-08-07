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
  final Map<String, Map<String, Unit>> unitsRepo = {};

  static UnitService build(final int count) {
    final UnitServiceMock mock = UnitServiceMock();
    final unitsRepo = mock.unitsRepo;
    when(mock.fetch(any)).thenAnswer((_) async {
      var incidentId = _.positionalArguments[0];
      var units = unitsRepo[incidentId];
      if (units == null) {
        units = unitsRepo.putIfAbsent(incidentId, () => {});
      }
      if (units.isEmpty) {
        units.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
                "${incidentId}u$i",
                Unit.fromJson(
                  UnitBuilder.createUnitAsJson("${incidentId}u$i", UnitType.Team, i, "${incidentId}t$i"),
                )),
        ]);
      }
      return ServiceResponse.ok(body: units.values.toList(growable: false));
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      final incidentId = _.positionalArguments[0];
      final Unit unit = _.positionalArguments[1];
      final units = unitsRepo[incidentId];
      if (units == null) {
        return ServiceResponse.notFound(message: "Not found. Incident $incidentId");
      }
      final String id = "${incidentId}u${units.length + 1}";
      return ServiceResponse.ok(body: units.putIfAbsent(id, () => unit.cloneWith(id: id)));
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      var incident = unitsRepo.entries.firstWhere((entry) => entry.value.containsKey(unit.id), orElse: null);
      if (incident != null) {
        incident.value.update(unit.id, (_) => unit, ifAbsent: () => unit);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Unit ${unit.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final Unit unit = _.positionalArguments[0];
      var incident = unitsRepo.entries.firstWhere((entry) => entry.value.containsKey(unit.id), orElse: null);
      if (incident != null) {
        incident.value.remove(unit.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Unit ${unit.id}");
    });
    return mock;
  }
}
