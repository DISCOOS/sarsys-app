// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConflictModel _$ConflictModelFromJson(Map json) {
  return ConflictModel(
    type: _$enumDecodeNullable(_$ConflictTypeEnumMap, json['type']),
    error: json['error'] as String,
    mine: (json['mine'] as List)
        ?.map((e) => (e as Map)?.map(
              (k, e) => MapEntry(k as String, e),
            ))
        ?.toList(),
    yours: (json['yours'] as List)
        ?.map((e) => (e as Map)?.map(
              (k, e) => MapEntry(k as String, e),
            ))
        ?.toList(),
  );
}

Map<String, dynamic> _$ConflictModelToJson(ConflictModel instance) =>
    <String, dynamic>{
      'type': _$ConflictTypeEnumMap[instance.type],
      'error': instance.error,
      'mine': instance.mine,
      'yours': instance.yours,
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

const _$ConflictTypeEnumMap = {
  ConflictType.merge: 'merge',
  ConflictType.exists: 'exists',
  ConflictType.deleted: 'deleted',
};
