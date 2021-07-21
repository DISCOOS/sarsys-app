// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TalkGroup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TalkGroup _$TalkGroupFromJson(Map json) {
  return TalkGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    type: _$enumDecodeNullable(_$TalkGroupTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$TalkGroupToJson(TalkGroup instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('name', instance.name);
  writeNotNull('type', _$TalkGroupTypeEnumMap[instance.type]);
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

const _$TalkGroupTypeEnumMap = {
  TalkGroupType.tetra: 'tetra',
  TalkGroupType.marine: 'marine',
  TalkGroupType.analog: 'analog',
};
