// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Security _$SecurityFromJson(Map<String, dynamic> json) {
  return Security(
    pin: json['pin'] as String,
    type: _$enumDecode(_$SecurityTypeEnumMap, json['type']),
    locked: json['locked'] as bool ?? true,
    trusted: json['trusted'] as bool,
    mode: _$enumDecodeNullable(_$SecurityModeEnumMap, json['mode']),
    heartbeat: json['heartbeat'] == null
        ? null
        : DateTime.parse(json['heartbeat'] as String),
  );
}

Map<String, dynamic> _$SecurityToJson(Security instance) => <String, dynamic>{
      'pin': instance.pin,
      'type': _$SecurityTypeEnumMap[instance.type],
      'locked': instance.locked,
      'trusted': instance.trusted,
      'heartbeat': instance.heartbeat?.toIso8601String(),
      'mode': _$SecurityModeEnumMap[instance.mode],
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

const _$SecurityModeEnumMap = {
  SecurityMode.personal: 'personal',
  SecurityMode.shared: 'shared',
};
