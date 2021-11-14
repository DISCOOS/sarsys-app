// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConflictModel _$ConflictModelFromJson(Map json) {
  return ConflictModel(
    type: _$enumDecodeNullable(_$ConflictTypeEnumMap, json['type']),
    code: json['code'] as String?,
    base: (json['base'] as Map?)?.map(
      (k, e) => MapEntry(k as String, e),
    ),
    mine: (json['mine'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    yours: (json['yours'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    error: json['error'] as String?,
    paths: (json['paths'] as List<dynamic>?)?.map((e) => e as String?).toList(),
  );
}

Map<String, dynamic> _$ConflictModelToJson(ConflictModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('code', instance.code);
  writeNotNull('error', instance.error);
  writeNotNull('type', _$ConflictTypeEnumMap[instance.type]);
  writeNotNull('paths', instance.paths);
  writeNotNull('base', instance.base);
  writeNotNull('mine', instance.mine);
  writeNotNull('yours', instance.yours);
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

const _$ConflictTypeEnumMap = {
  ConflictType.merge: 'merge',
  ConflictType.exists: 'exists',
  ConflictType.deleted: 'deleted',
};
