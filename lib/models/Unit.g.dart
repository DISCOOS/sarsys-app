// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map<String, dynamic> json) {
  return Unit(
      id: json['id'] as String,
      type: _$enumDecodeNullable(_$UnitTypeEnumMap, json['type']),
      name: json['name'] as String,
      tracking: json['tracking'] as String);
}

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$UnitTypeEnumMap[instance.type],
      'name': instance.name,
      'tracking': instance.tracking
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$UnitTypeEnumMap = <UnitType, dynamic>{
  UnitType.Team: 'Team',
  UnitType.K9: 'K9',
  UnitType.Boat: 'Boat',
  UnitType.Vehicle: 'Vehicle',
  UnitType.Snowmobile: 'Snowmobile',
  UnitType.ATV: 'ATV',
  UnitType.Other: 'Other'
};
