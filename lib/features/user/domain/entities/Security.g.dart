// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Security _$SecurityFromJson(Map json) {
  return Security(
    pin: json['pin'] as String,
    type: _$enumDecodeNullable(_$SecurityTypeEnumMap, json['type']),
    locked: json['locked'] as bool ?? true,
    trusted: json['trusted'] as bool,
    mode: _$enumDecodeNullable(_$SecurityModeEnumMap, json['mode']),
    heartbeat: json['heartbeat'] == null
        ? null
        : DateTime.parse(json['heartbeat'] as String),
  );
}

Map<String, dynamic> _$SecurityToJson(Security instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('pin', instance.pin);
  writeNotNull('type', _$SecurityTypeEnumMap[instance.type]);
  writeNotNull('locked', instance.locked);
  writeNotNull('trusted', instance.trusted);
  writeNotNull('heartbeat', instance.heartbeat?.toIso8601String());
  writeNotNull('mode', _$SecurityModeEnumMap[instance.mode]);
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

const _$SecurityTypeEnumMap = {
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint',
};

const _$SecurityModeEnumMap = {
  SecurityMode.personal: 'personal',
  SecurityMode.shared: 'shared',
};
