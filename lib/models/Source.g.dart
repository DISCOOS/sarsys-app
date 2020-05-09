// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Source _$SourceFromJson(Map json) {
  return Source(
    uuid: json['uuid'] as String,
    type: _$enumDecodeNullable(_$SourceTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$SourceToJson(Source instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'type': _$SourceTypeEnumMap[instance.type],
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

const _$SourceTypeEnumMap = {
  SourceType.device: 'device',
  SourceType.trackable: 'trackable',
};
