import 'dart:convert';

import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:mockito/mockito.dart';

class UnitsBuilder {
  static createUnitAsJson(String id, UnitType type, String name) {
    return json.decode('{'
        '"id": "$id",'
        '"type": "${enumName(type)}",'
        '"name": "$name"'
        '}');
  }
}

class UnitServiceMock extends Mock implements UnitService {
  static UnitService build(final int count) {
    final UnitServiceMock mock = UnitServiceMock();
    when(mock.fetch()).thenAnswer((_) async {
      return Future.value([
        for (var i = 1; i <= count; i++)
          Unit.fromJson(
              UnitsBuilder.createUnitAsJson("u$i", UnitType.Team, "${translateDeviceType(UnitType.Team)} $i")),
      ]);
    });
    return mock;
  }
}
