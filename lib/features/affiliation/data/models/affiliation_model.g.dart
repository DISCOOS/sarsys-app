// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'affiliation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AffiliationModel _$AffiliationModelFromJson(Map json) {
  return AffiliationModel(
    uuid: json['uuid'] as String?,
    div: toDivRef(json['div']),
    dep: toDepRef(json['dep']),
    org: toOrgRef(json['org']),
    active: json['active'] as bool?,
    person: json['person'] == null
        ? null
        : PersonModel.fromJson(
            Map<String, dynamic>.from(json['person'] as Map)),
    type: _$enumDecodeNullable(_$AffiliationTypeEnumMap, json['type']),
    status:
        _$enumDecodeNullable(_$AffiliationStandbyStatusEnumMap, json['status']),
  );
}

Map<String, dynamic> _$AffiliationModelToJson(AffiliationModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('type', _$AffiliationTypeEnumMap[instance.type]);
  writeNotNull('status', _$AffiliationStandbyStatusEnumMap[instance.status]);
  writeNotNull('active', instance.active);
  writeNotNull('person', instance.person?.toJson());
  writeNotNull('org', instance.org?.toJson());
  writeNotNull('div', instance.div?.toJson());
  writeNotNull('dep', instance.dep?.toJson());
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

const _$AffiliationTypeEnumMap = {
  AffiliationType.member: 'member',
  AffiliationType.employee: 'employee',
  AffiliationType.external: 'external',
  AffiliationType.volunteer: 'volunteer',
};

const _$AffiliationStandbyStatusEnumMap = {
  AffiliationStandbyStatus.available: 'available',
  AffiliationStandbyStatus.short_notice: 'short_notice',
  AffiliationStandbyStatus.unavailable: 'unavailable',
};
