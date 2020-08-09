// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map json) {
  return Track(
    id: json['id'] as String,
    status: _$enumDecodeNullable(_$TrackStatusEnumMap, json['status']),
    source: json['source'] == null
        ? null
        : Source.fromJson((json['source'] as Map)?.map(
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

Map<String, dynamic> _$TrackToJson(Track instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('source', instance.source?.toJson());
  writeNotNull('status', _$TrackStatusEnumMap[instance.status]);
  writeNotNull(
      'positions', instance.positions?.map((e) => e?.toJson())?.toList());
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
