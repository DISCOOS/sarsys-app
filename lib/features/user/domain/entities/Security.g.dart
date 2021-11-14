// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Security _$SecurityFromJson(Map json) {
  return Security(
    pin: json['pin'] as String?,
    type: _$enumDecodeNullable(_$SecurityTypeEnumMap, json['type']),
    mode: _$enumDecodeNullable(_$SecurityModeEnumMap, json['mode']),
    locked: json['locked'] as bool? ?? true,
    trusted: json['trusted'] as bool?,
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
  writeNotNull('trusted', instance.trusted);
  writeNotNull('type', _$SecurityTypeEnumMap[instance.type]);
  val['heartbeat'] = instance.heartbeat.toIso8601String();
  writeNotNull('mode', _$SecurityModeEnumMap[instance.mode]);
  writeNotNull('locked', instance.locked);
  return val;
}

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
}

const _$SecurityTypeEnumMap = {
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint',
};

const _$SecurityModeEnumMap = {
  SecurityMode.personal: 'personal',
  SecurityMode.shared: 'shared',
};
