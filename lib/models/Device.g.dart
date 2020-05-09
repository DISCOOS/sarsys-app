// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map json) {
  return Device(
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

Map<String, dynamic> _$DeviceToJson(Device instance) {
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
  DeviceType.Tetra: 'Tetra',
  DeviceType.App: 'App',
  DeviceType.APRS: 'APRS',
  DeviceType.AIS: 'AIS',
  DeviceType.Spot: 'Spot',
  DeviceType.InReach: 'InReach',
};

const _$DeviceStatusEnumMap = {
  DeviceStatus.Unavailable: 'Unavailable',
  DeviceStatus.Available: 'Available',
};
