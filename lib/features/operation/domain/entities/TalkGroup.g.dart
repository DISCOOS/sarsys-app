// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TalkGroup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TalkGroup _$TalkGroupFromJson(Map json) {
  return TalkGroup(
    name: json['name'] as String,
    type: _$enumDecodeNullable(_$TalkGroupTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$TalkGroupToJson(TalkGroup instance) => <String, dynamic>{
      'name': instance.name,
      'type': _$TalkGroupTypeEnumMap[instance.type],
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

const _$TalkGroupTypeEnumMap = {
  TalkGroupType.tetra: 'tetra',
  TalkGroupType.marine: 'marine',
  TalkGroupType.analog: 'analog',
};
