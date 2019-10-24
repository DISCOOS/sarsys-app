// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map<String, dynamic> json) {
  return Track(
      points: json['points'] as List,
      type: _$enumDecodeNullable(_$TrackTypeEnumMap, json['type']));
}

Map<String, dynamic> _$TrackToJson(Track instance) => <String, dynamic>{
      'type': _$TrackTypeEnumMap[instance.type],
      'points': instance.points
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

const _$TrackTypeEnumMap = <TrackType, dynamic>{
  TrackType.Device: 'Device',
  TrackType.Personnel: 'Personnel'
};
