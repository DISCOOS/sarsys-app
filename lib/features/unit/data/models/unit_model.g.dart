// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnitModel _$UnitModelFromJson(Map json) {
  return UnitModel(
    uuid: json['uuid'] as String,
    type: _$enumDecodeNullable(_$UnitTypeEnumMap, json['type']),
    number: json['number'] as int,
    status: _$enumDecodeNullable(_$UnitStatusEnumMap, json['status']),
    callsign: json['callsign'] as String,
    phone: json['phone'] as String,
    personnels: (json['personnels'] as List)
        ?.map((e) => e == null
            ? null
            : PersonnelModel.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    tracking: toTrackingRef(json['tracking']),
  );
}

Map<String, dynamic> _$UnitModelToJson(UnitModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uuid', instance.uuid);
  writeNotNull('tracking', instance.tracking?.toJson());
  writeNotNull('number', instance.number);
  writeNotNull('type', _$UnitTypeEnumMap[instance.type]);
  writeNotNull('status', _$UnitStatusEnumMap[instance.status]);
  writeNotNull('phone', instance.phone);
  writeNotNull('callsign', instance.callsign);
  writeNotNull(
      'personnels', instance.personnels?.map((e) => e?.toJson())?.toList());
  return val;
}

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
  UnitType.team: 'team',
  UnitType.k9: 'k9',
  UnitType.boat: 'boat',
  UnitType.vehicle: 'vehicle',
  UnitType.snowmobile: 'snowmobile',
  UnitType.atv: 'atv',
  UnitType.commandpost: 'commandpost',
  UnitType.other: 'other',
};

const _$UnitStatusEnumMap = {
  UnitStatus.mobilized: 'mobilized',
  UnitStatus.deployed: 'deployed',
  UnitStatus.retired: 'retired',
};
