// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) {
  return Device(
      id: json['id'] as String,
      type: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['type']),
      alias: json['alias'] as String,
      number: json['number'] as String,
      point: json['point'] == null
          ? null
          : Point.fromJson(json['point'] as Map<String, dynamic>),
      manual: json['manual'] as bool,
      status: _$enumDecodeNullable(_$DeviceStatusEnumMap, json['status']));
}

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$DeviceTypeEnumMap[instance.type],
      'status': _$DeviceStatusEnumMap[instance.status],
      'number': instance.number,
      'alias': instance.alias,
      'point': instance.point?.toJson(),
      'manual': instance.manual
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

const _$DeviceTypeEnumMap = <DeviceType, dynamic>{
  DeviceType.Tetra: 'Tetra',
  DeviceType.App: 'App',
  DeviceType.APRS: 'APRS',
  DeviceType.AIS: 'AIS'
};

const _$DeviceStatusEnumMap = <DeviceStatus, dynamic>{
  DeviceStatus.Attached: 'Attached',
  DeviceStatus.Detached: 'Detached'
};
