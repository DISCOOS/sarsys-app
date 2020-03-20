// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map json) {
  return Unit(
    id: json['id'] as String,
    type: _$enumDecodeNullable(_$UnitTypeEnumMap, json['type']),
    number: json['number'] as int,
    status: _$enumDecodeNullable(_$UnitStatusEnumMap, json['status']),
    callsign: json['callsign'] as String,
    phone: json['phone'] as String,
    tracking: json['tracking'] as String,
    personnel: (json['personnel'] as List)
        ?.map((e) => e == null
            ? null
            : Personnel.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
  );
}

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'type': _$UnitTypeEnumMap[instance.type],
      'status': _$UnitStatusEnumMap[instance.status],
      'phone': instance.phone,
      'callsign': instance.callsign,
      'tracking': instance.tracking,
      'personnel': instance.personnel?.map((e) => e?.toJson())?.toList(),
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$UnitTypeEnumMap = {
  UnitType.Team: 'Team',
  UnitType.K9: 'K9',
  UnitType.Boat: 'Boat',
  UnitType.Vehicle: 'Vehicle',
  UnitType.Snowmobile: 'Snowmobile',
  UnitType.ATV: 'ATV',
  UnitType.CommandPost: 'CommandPost',
  UnitType.Other: 'Other',
};

const _$UnitStatusEnumMap = {
  UnitStatus.Mobilized: 'Mobilized',
  UnitStatus.Deployed: 'Deployed',
  UnitStatus.Retired: 'Retired',
};
