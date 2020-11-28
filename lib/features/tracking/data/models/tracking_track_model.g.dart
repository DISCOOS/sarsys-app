// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_track_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackingTrackModel _$TrackingTrackModelFromJson(Map json) {
  return TrackingTrackModel(
    id: json['id'] as String,
    status: _$enumDecodeNullable(_$TrackStatusEnumMap, json['status']),
    source: json['source'] == null
        ? null
        : TrackingSourceModel.fromJson((json['source'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    positions: (json['positions'] as List)
        ?.map((e) => e == null
            ? null
            : Position.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
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
      'positions', instance.positions?.map((e) => e?.toJson())?.toList());
  writeNotNull('source', instance.source?.toJson());
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

const _$TrackStatusEnumMap = {
  TrackStatus.attached: 'attached',
  TrackStatus.detached: 'detached',
};
