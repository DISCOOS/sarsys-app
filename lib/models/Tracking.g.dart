// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Tracking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tracking _$TrackingFromJson(Map json) {
  return Tracking(
    uuid: json['uuid'] as String,
    status: _$enumDecodeNullable(_$TrackingStatusEnumMap, json['status']),
    position: json['position'] == null
        ? null
        : Position.fromJson((json['position'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    distance: (json['distance'] as num)?.toDouble(),
    speed: (json['speed'] as num)?.toDouble(),
    effort: json['effort'] == null
        ? null
        : Duration(microseconds: json['effort'] as int),
    sources: (json['sources'] as List)
        ?.map((e) => e == null
            ? null
            : Source.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    history: (json['history'] as List)
        ?.map((e) => e == null
            ? null
            : Position.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    tracks: (json['tracks'] as List)
        ?.map((e) => e == null
            ? null
            : Track.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
  );
}

Map<String, dynamic> _$TrackingToJson(Tracking instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'position': instance.position?.toJson(),
      'status': _$TrackingStatusEnumMap[instance.status],
      'speed': instance.speed,
      'effort': instance.effort?.inMicroseconds,
      'distance': instance.distance,
      'sources': instance.sources?.map((e) => e?.toJson())?.toList(),
      'history': instance.history?.map((e) => e?.toJson())?.toList(),
      'tracks': instance.tracks?.map((e) => e?.toJson())?.toList(),
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

const _$TrackingStatusEnumMap = {
  TrackingStatus.none: 'none',
  TrackingStatus.created: 'created',
  TrackingStatus.tracking: 'tracking',
  TrackingStatus.paused: 'paused',
  TrackingStatus.closed: 'closed',
};
