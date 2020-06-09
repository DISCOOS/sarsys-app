// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map json) {
  return DeviceModel(
    uuid: json['uuid'] as String,
    type: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['type']),
    alias: json['alias'] as String,
    number: json['number'] as String,
    manual: json['manual'] as bool,
    network: json['network'] as String,
    networkId: json['networkId'] as String,
    allocatedTo: toIncidentRef(json['allocatedTo']),
    position: json['position'] == null
        ? null
        : Position.fromJson((json['position'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    status: _$enumDecodeNullable(_$DeviceStatusEnumMap, json['status']),
  );
}

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
    'position': instance.position?.toJson(),
    'manual': instance.manual,
    'type': _$DeviceTypeEnumMap[instance.type],
    'status': _$DeviceStatusEnumMap[instance.status],
    'number': instance.number,
    'alias': instance.alias,
    'network': instance.network,
    'networkId': instance.networkId,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('allocatedTo', instance.allocatedTo?.toJson());
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

const _$DeviceTypeEnumMap = {
  DeviceType.tetra: 'tetra',
  DeviceType.app: 'app',
  DeviceType.aprs: 'aprs',
  DeviceType.ais: 'ais',
  DeviceType.spot: 'spot',
  DeviceType.inreach: 'inreach',
};

const _$DeviceStatusEnumMap = {
  DeviceStatus.unavailable: 'unavailable',
  DeviceStatus.available: 'available',
};
