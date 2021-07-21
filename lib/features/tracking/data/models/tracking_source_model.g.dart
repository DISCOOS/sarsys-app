// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_source_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackingSourceModel _$TrackingSourceModelFromJson(Map json) {
  return TrackingSourceModel(
    uuid: json['uuid'] as String,
    type: _$enumDecodeNullable(_$SourceTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$TrackingSourceModelToJson(TrackingSourceModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uuid', instance.uuid);
  writeNotNull('type', _$SourceTypeEnumMap[instance.type]);
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

const _$SourceTypeEnumMap = {
  SourceType.device: 'device',
  SourceType.trackable: 'trackable',
};
