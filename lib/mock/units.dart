import 'dart:convert';

import 'package:SarSys/models/Unit.dart';
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
    final UnitServiceMock mock = UnitServiceMock();
    when(mock.fetch(any)).thenAnswer((id) async {
      return Future.value([
        for (var i = 1; i <= count; i++)
          Unit.fromJson(
            UnitBuilder.createUnitAsJson("u$i", UnitType.Team, i, "t$i"),
          ),
      ]);
    });
    return mock;
  }
}
