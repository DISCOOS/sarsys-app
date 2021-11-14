// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map json) {
  return DeviceModel(
    uuid: json['uuid'] as String?,
    type: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['type']),
    alias: json['alias'] as String?,
    number: json['number'] as String?,
    manual: json['manual'] as bool?,
    trackable: json['trackable'] as bool?,
    network: json['network'] as String?,
    networkId: json['networkId'] as String?,
    allocatedTo: toIncidentRef(json['allocatedTo']),
    position: json['position'] == null
        ? null
        : Position.fromJson(Map<String, dynamic>.from(json['position'] as Map)),
    status: _$enumDecodeNullable(_$DeviceStatusEnumMap, json['status']),
  );
}

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('position', instance.position?.toJson());
  writeNotNull('manual', instance.manual);
  writeNotNull('type', _$DeviceTypeEnumMap[instance.type]);
  writeNotNull('status', _$DeviceStatusEnumMap[instance.status]);
  writeNotNull('number', instance.number);
  writeNotNull('alias', instance.alias);
  writeNotNull('trackable', instance.trackable);
  writeNotNull('network', instance.network);
  writeNotNull('networkId', instance.networkId);
  writeNotNull('allocatedTo', instance.allocatedTo?.toJson());
  return val;
}

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
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
