// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map<String, dynamic> json) {
  return $checkedNew('Unit', json, () {
    final val = Unit(
        id: $checkedConvert(json, 'id', (v) => v as String),
        type: $checkedConvert(
            json, 'type', (v) => _$enumDecodeNullable(_$UnitTypeEnumMap, v)),
        number: $checkedConvert(json, 'number', (v) => v as int),
        status: $checkedConvert(json, 'status',
            (v) => _$enumDecodeNullable(_$UnitStatusEnumMap, v)),
        callsign: $checkedConvert(json, 'callsign', (v) => v as String),
        phone: $checkedConvert(json, 'phone', (v) => v as String),
        tracking: $checkedConvert(json, 'tracking', (v) => v as String),
        personnel: $checkedConvert(
            json,
            'personnel',
            (v) => (v as List)
                ?.map((e) => e == null ? null : Personnel.fromJson(e))
                ?.toList()));
    return val;
  });
}

Map<String, dynamic> _$UnitToJson(Unit instance) =>
    _$UnitJsonMapWrapper(instance);

class _$UnitJsonMapWrapper extends $JsonMapWrapper {
  final Unit _v;
  _$UnitJsonMapWrapper(this._v);

  @override
  Iterable<String> get keys => const [
        'id',
        'number',
        'type',
        'status',
        'phone',
        'callsign',
        'tracking',
        'personnel'
      ];

  @override
  dynamic operator [](Object key) {
    if (key is String) {
      switch (key) {
        case 'id':
          return _v.id;
        case 'number':
          return _v.number;
        case 'type':
          return _$UnitTypeEnumMap[_v.type];
        case 'status':
          return _$UnitStatusEnumMap[_v.status];
        case 'phone':
          return _v.phone;
        case 'callsign':
          return _v.callsign;
        case 'tracking':
          return _v.tracking;
        case 'personnel':
          return $wrapListHandleNull<Personnel>(
              _v.personnel, (e) => e?.toJson());
      }
    }
    return null;
  }
}

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
  UnitType.CommandPost: 'CommandPost',
  UnitType.Other: 'Other'
};

const _$UnitStatusEnumMap = <UnitStatus, dynamic>{
  UnitStatus.Mobilized: 'Mobilized',
  UnitStatus.Deployed: 'Deployed',
  UnitStatus.Retired: 'Retired'
};
