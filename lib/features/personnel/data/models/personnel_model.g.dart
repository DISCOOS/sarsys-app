// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personnel_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonnelModel _$PersonnelModelFromJson(Map json) {
  return PersonnelModel(
    uuid: json['uuid'] as String,
    person: json['person'] == null
        ? null
        : PersonModel.fromJson((json['person'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    tracking: toTrackingRef(json['tracking']),
    operation: toOperationRef(json['operation']),
    affiliation: toAffiliationRef(json['affiliation']),
    status: _$enumDecodeNullable(_$PersonnelStatusEnumMap, json['status']),
    unit: toUnitRef(json['unit']),
    function: _$enumDecodeNullable(
        _$OperationalFunctionTypeEnumMap, json['function']),
  );
}

Map<String, dynamic> _$PersonnelModelToJson(PersonnelModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uuid', instance.uuid);
  writeNotNull('status', _$PersonnelStatusEnumMap[instance.status]);
  writeNotNull('function', _$OperationalFunctionTypeEnumMap[instance.function]);
  writeNotNull('person', instance.person?.toJson());
  writeNotNull('unit', instance.unit?.toJson());
  writeNotNull('operation', instance.operation?.toJson());
  writeNotNull('tracking', instance.tracking?.toJson());
  writeNotNull('affiliation', instance.affiliation?.toJson());
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

const _$PersonnelStatusEnumMap = {
  PersonnelStatus.alerted: 'alerted',
  PersonnelStatus.enroute: 'enroute',
  PersonnelStatus.onscene: 'onscene',
  PersonnelStatus.leaving: 'leaving',
  PersonnelStatus.retired: 'retired',
};

const _$OperationalFunctionTypeEnumMap = {
  OperationalFunctionType.personnel: 'personnel',
  OperationalFunctionType.unit_leader: 'unit_leader',
  OperationalFunctionType.commander: 'commander',
};
