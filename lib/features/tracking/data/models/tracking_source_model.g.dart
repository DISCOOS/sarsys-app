// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_source_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackingSourceModel _$TrackingSourceModelFromJson(Map json) {
  return TrackingSourceModel(
    uuid: json['uuid'] as String?,
    type: _$enumDecodeNullable(_$SourceTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$TrackingSourceModelToJson(TrackingSourceModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', _$SourceTypeEnumMap[instance.type]);
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

const _$SourceTypeEnumMap = {
  SourceType.device: 'device',
  SourceType.trackable: 'trackable',
};
