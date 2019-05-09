// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TalkGroup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TalkGroup _$TalkGroupFromJson(Map<String, dynamic> json) {
  return TalkGroup(
      name: json['name'] as String,
      type: _$enumDecodeNullable(_$TalkGroupTypeEnumMap, json['type']));
}

Map<String, dynamic> _$TalkGroupToJson(TalkGroup instance) => <String, dynamic>{
      'name': instance.name,
      'type': _$TalkGroupTypeEnumMap[instance.type]
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

const _$TalkGroupTypeEnumMap = <TalkGroupType, dynamic>{
  TalkGroupType.Tetra: 'Tetra',
  TalkGroupType.Marine: 'Marine',
  TalkGroupType.Analog: 'Analog'
};
