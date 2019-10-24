// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Tracking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tracking _$TrackingFromJson(Map<String, dynamic> json) {
  return Tracking(
      id: json['id'] as String,
      status: _$enumDecodeNullable(_$TrackingStatusEnumMap, json['status']),
      point: json['point'] == null ? null : Point.fromJson(json['point'] as Map<String, dynamic>),
      distance: (json['distance'] as num)?.toDouble(),
      speed: (json['speed'] as num)?.toDouble(),
      effort: json['effort'] == null ? null : Duration(microseconds: json['effort'] as int),
      devices: (json['devices'] as List)?.map((e) => e as String)?.toList(),
      history:
          (json['history'] as List)?.map((e) => e == null ? null : Point.fromJson(e as Map<String, dynamic>))?.toList(),
      tracks: (json['tracks'] as Map<String, dynamic>)?.map(
        (k, e) => MapEntry(k, e == null ? null : Track.fromJson(e as Map<String, dynamic>)),
      ),
      aggregates: (json['personnel'] as List)?.map((e) => e as String)?.toList());
}

Map<String, dynamic> _$TrackingToJson(Tracking instance) => <String, dynamic>{
      'id': instance.id,
      'status': _$TrackingStatusEnumMap[instance.status],
      'point': instance.point?.toJson(),
      'distance': instance.distance,
      'speed': instance.speed,
      'effort': instance.effort?.inMicroseconds,
      'devices': instance.devices,
      'history': instance.history?.map((e) => e?.toJson())?.toList(),
      'personnel': instance.aggregates,
      'tracks': instance.tracks?.map((k, e) => MapEntry(k, e?.toJson()))
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError('`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$TrackingStatusEnumMap = <TrackingStatus, dynamic>{
  TrackingStatus.None: 'None',
  TrackingStatus.Created: 'Created',
  TrackingStatus.Tracking: 'Tracking',
  TrackingStatus.Paused: 'Paused',
  TrackingStatus.Closed: 'Closed'
};
