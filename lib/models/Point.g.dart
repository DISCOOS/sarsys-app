// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Point _$PointFromJson(Map<String, dynamic> json) {
  return Point(
      lat: (json['lat'] as num)?.toDouble(),
      lon: (json['lon'] as num)?.toDouble(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      alt: (json['alt'] as num)?.toDouble(),
      acc: (json['acc'] as num)?.toDouble(),
      type: _$enumDecodeNullable(_$PointTypeEnumMap, json['type']));
}

Map<String, dynamic> _$PointToJson(Point instance) => <String, dynamic>{
      'lat': instance.lat,
      'lon': instance.lon,
      'alt': instance.alt,
      'acc': instance.acc,
      'timestamp': instance.timestamp?.toIso8601String(),
      'type': _$PointTypeEnumMap[instance.type]
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

const _$PointTypeEnumMap = <PointType, dynamic>{
  PointType.Manual: 'Manual',
  PointType.Device: 'Device',
  PointType.Aggregated: 'Aggregated'
};
