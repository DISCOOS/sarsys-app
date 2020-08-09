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

Map<String, dynamic> _$PositionToJson(Position instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('geometry', instance.geometry?.toJson());
  writeNotNull('properties', instance.properties?.toJson());
  return val;
}

PositionProperties _$PositionPropertiesFromJson(Map json) {
  return PositionProperties(
    acc: (json['accuracy'] as num)?.toDouble(),
    timestamp: json['timestamp'] == null
        ? null
        : DateTime.parse(json['timestamp'] as String),
    speed: (json['speed'] as num)?.toDouble(),
    bearing: (json['bearing'] as num)?.toDouble(),
    isMoving: json['isMoving'] as bool,
    activity: json['activity'] == null
        ? null
        : Activity.fromJson((json['activity'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    source: _$enumDecodeNullable(_$PositionSourceEnumMap, json['source']),
  );
}

Map<String, dynamic> _$PositionPropertiesToJson(PositionProperties instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('accuracy', instance.acc);
  writeNotNull('speed', instance.speed);
  writeNotNull('bearing', instance.bearing);
  writeNotNull('isMoving', instance.isMoving);
  writeNotNull('activity', instance.activity?.toJson());
  writeNotNull('timestamp', instance.timestamp?.toIso8601String());
  writeNotNull('source', _$PositionSourceEnumMap[instance.source]);
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

const _$PositionSourceEnumMap = {
  PositionSource.manual: 'manual',
  PositionSource.device: 'device',
  PositionSource.aggregate: 'aggregate',
};

Activity _$ActivityFromJson(Map json) {
  return Activity(
    type: _$enumDecodeNullable(_$ActivityTypeEnumMap, json['type']),
    confidence: json['confidence'] as int,
  );
}

Map<String, dynamic> _$ActivityToJson(Activity instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', _$ActivityTypeEnumMap[instance.type]);
  writeNotNull('confidence', instance.confidence);
  return val;
}

const _$ActivityTypeEnumMap = {
  ActivityType.still: 'still',
  ActivityType.on_foot: 'on_foot',
  ActivityType.walking: 'walking',
  ActivityType.running: 'running',
  ActivityType.unknown: 'unknown',
  ActivityType.on_bicycle: 'on_bicycle',
  ActivityType.in_vehicle: 'in_vehicle',
};
