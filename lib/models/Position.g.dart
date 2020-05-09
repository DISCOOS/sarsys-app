// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Position _$PositionFromJson(Map json) {
  return Position(
    geometry: json['geometry'] == null
        ? null
        : Point.fromJson((json['geometry'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    properties: json['properties'] == null
        ? null
        : PositionProperties.fromJson((json['properties'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
  );
}

Map<String, dynamic> _$PositionToJson(Position instance) => <String, dynamic>{
      'geometry': instance.geometry?.toJson(),
      'properties': instance.properties?.toJson(),
    };

PositionProperties _$PositionPropertiesFromJson(Map json) {
  return PositionProperties(
    acc: (json['accuracy'] as num)?.toDouble(),
    timestamp: json['timestamp'] == null
        ? null
        : DateTime.parse(json['timestamp'] as String),
    speed: (json['speed'] as num)?.toDouble(),
    bearing: (json['bearing'] as num)?.toDouble(),
    source: _$enumDecodeNullable(_$PositionSourceEnumMap, json['source']),
  );
}

Map<String, dynamic> _$PositionPropertiesToJson(PositionProperties instance) =>
    <String, dynamic>{
      'accuracy': instance.acc,
      'speed': instance.speed,
      'bearing': instance.bearing,
      'timestamp': instance.timestamp?.toIso8601String(),
      'source': _$PositionSourceEnumMap[instance.source],
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

const _$PositionSourceEnumMap = {
  PositionSource.manual: 'manual',
  PositionSource.device: 'device',
  PositionSource.aggregate: 'aggregate',
};
