// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Tracking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tracking _$TrackingFromJson(Map<String, dynamic> json) {
  return Tracking(
      id: json['id'] as String,
      status: _$enumDecodeNullable(_$TrackingStatusEnumMap, json['status']),
      point: json['point'] == null
          ? null
          : Point.fromJson(json['point'] as Map<String, dynamic>),
      distance: (json['distance'] as num)?.toDouble(),
      speed: (json['speed'] as num)?.toDouble(),
      effort: json['effort'] == null
          ? null
          : Duration(microseconds: json['effort'] as int),
      devices: (json['devices'] as List)?.map((e) => e as String)?.toList(),
      history: (json['history'] as List)
          ?.map((e) =>
              e == null ? null : Point.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      tracks: json['tracks'],
      aggregates:
          (json['aggregates'] as List)?.map((e) => e as String)?.toList());
}

Map<String, dynamic> _$TrackingToJson(Tracking instance) =>
    _$TrackingJsonMapWrapper(instance);

class _$TrackingJsonMapWrapper extends $JsonMapWrapper {
  final Tracking _v;
  _$TrackingJsonMapWrapper(this._v);

  @override
  Iterable<String> get keys => const [
        'id',
        'status',
        'point',
        'distance',
        'speed',
        'effort',
        'devices',
        'history',
        'aggregates',
        'tracks'
      ];

  @override
  dynamic operator [](Object key) {
    if (key is String) {
      switch (key) {
        case 'id':
          return _v.id;
        case 'status':
          return _$TrackingStatusEnumMap[_v.status];
        case 'point':
          return _v.point?.toJson();
        case 'distance':
          return _v.distance;
        case 'speed':
          return _v.speed;
        case 'effort':
          return _v.effort?.inMicroseconds;
        case 'devices':
          return _v.devices;
        case 'history':
          return $wrapListHandleNull<Point>(_v.history, (e) => e?.toJson());
        case 'aggregates':
          return _v.aggregates;
        case 'tracks':
          return _v.tracks;
      }
    }
    return null;
  }
}

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

const _$TrackingStatusEnumMap = <TrackingStatus, dynamic>{
  TrackingStatus.None: 'None',
  TrackingStatus.Created: 'Created',
  TrackingStatus.Tracking: 'Tracking',
  TrackingStatus.Paused: 'Paused',
  TrackingStatus.Closed: 'Closed'
};
