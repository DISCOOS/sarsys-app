// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_track_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackingTrackModel _$TrackingTrackModelFromJson(Map json) {
  return TrackingTrackModel(
    id: json['id'] as String?,
    status: _$enumDecodeNullable(_$TrackStatusEnumMap, json['status']),
    source: TrackingSourceModel.fromJson(
        Map<String, dynamic>.from(json['source'] as Map)),
    positions: (json['positions'] as List<dynamic>?)
        ?.map((e) => e == null
            ? null
            : Position.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

Map<String, dynamic> _$TrackingTrackModelToJson(TrackingTrackModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('status', _$TrackStatusEnumMap[instance.status]);
  writeNotNull(
      'positions', instance.positions?.map((e) => e?.toJson()).toList());
  val['source'] = instance.source.toJson();
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

const _$TrackStatusEnumMap = {
  TrackStatus.attached: 'attached',
  TrackStatus.detached: 'detached',
};
