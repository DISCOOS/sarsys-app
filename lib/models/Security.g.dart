// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Security _$SecurityFromJson(Map<String, dynamic> json) {
  return Security(
    json['pin'] as String,
    _$enumDecode(_$SecurityTypeEnumMap, json['type']),
    json['locked'] as bool ?? true,
    json['paused'] == null ? null : DateTime.parse(json['paused'] as String),
  );
}

Map<String, dynamic> _$SecurityToJson(Security instance) => <String, dynamic>{
      'pin': instance.pin,
      'type': _$SecurityTypeEnumMap[instance.type],
      'locked': instance.locked,
      'paused': instance.paused?.toIso8601String(),
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

const _$SecurityTypeEnumMap = {
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint',
};