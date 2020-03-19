// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Security _$SecurityFromJson(Map<String, dynamic> json) {
  return Security(
      json['pin'] as String,
      _$enumDecode(_$SecurityTypeEnumMap, json['type']),
      json['locked'] as bool ?? true);
}

Map<String, dynamic> _$SecurityToJson(Security instance) => <String, dynamic>{
      'pin': instance.pin,
      'type': _$SecurityTypeEnumMap[instance.type],
      'locked': instance.locked
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

const _$SecurityTypeEnumMap = <SecurityType, dynamic>{
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint'
};
