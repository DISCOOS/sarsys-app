// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackingModel _$TrackingModelFromJson(Map json) {
  return TrackingModel(
    uuid: json['uuid'] as String,
    status: _$enumDecodeNullable(_$TrackingStatusEnumMap, json['status']),
    position: json['position'] == null
        ? null
        : Position.fromJson(Map<String, dynamic>.from(json['position'] as Map)),
    distance: (json['distance'] as num?)?.toDouble(),
    speed: (json['speed'] as num?)?.toDouble(),
    effort: json['effort'] == null
        ? null
        : Duration(microseconds: json['effort'] as int),
    tracks: (json['tracks'] as List<dynamic>?)
        ?.map((e) =>
            TrackingTrackModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    sources: (json['sources'] as List<dynamic>?)
        ?.map((e) =>
            TrackingSourceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    history: (json['history'] as List<dynamic>?)
        ?.map((e) => e == null
            ? null
            : Position.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

Map<String, dynamic> _$TrackingModelToJson(TrackingModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('position', instance.position?.toJson());
  writeNotNull('speed', instance.speed);
  writeNotNull('effort', instance.effort?.inMicroseconds);
  writeNotNull('distance', instance.distance);
  writeNotNull('status', _$TrackingStatusEnumMap[instance.status]);
  val['history'] = instance.history.map((e) => e?.toJson()).toList();
  val['sources'] = instance.sources.map((e) => e.toJson()).toList();
  val['tracks'] = instance.tracks.map((e) => e.toJson()).toList();
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

const _$TrackingStatusEnumMap = {
  TrackingStatus.none: 'none',
  TrackingStatus.ready: 'ready',
  TrackingStatus.tracking: 'tracking',
  TrackingStatus.paused: 'paused',
  TrackingStatus.closed: 'closed',
};
