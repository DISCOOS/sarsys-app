// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) {
  return Device(
      id: json['id'] as String,
      type: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['type']),
      number: json['number'] as String);
}

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$DeviceTypeEnumMap[instance.type],
      'number': instance.number
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
  DeviceType.Mobile: 'Mobile',
  DeviceType.APRS: 'APRS',
  DeviceType.AIS: 'AIS'
};
