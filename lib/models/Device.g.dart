// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map json) {
  return Device(
    id: json['id'] as String,
    type: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['type']),
    alias: json['alias'] as String,
    number: json['number'] as String,
    point: json['point'] == null
        ? null
        : Point.fromJson((json['point'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    manual: json['manual'] as bool,
    status: _$enumDecodeNullable(_$DeviceStatusEnumMap, json['status']),
  );
}

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$DeviceTypeEnumMap[instance.type],
      'status': _$DeviceStatusEnumMap[instance.status],
      'number': instance.number,
      'alias': instance.alias,
      'point': instance.point?.toJson(),
      'manual': instance.manual,
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

const _$DeviceTypeEnumMap = {
  DeviceType.Tetra: 'Tetra',
  DeviceType.App: 'App',
  DeviceType.APRS: 'APRS',
  DeviceType.AIS: 'AIS',
};

const _$DeviceStatusEnumMap = {
  DeviceStatus.Attached: 'Attached',
  DeviceStatus.Detached: 'Detached',
};
