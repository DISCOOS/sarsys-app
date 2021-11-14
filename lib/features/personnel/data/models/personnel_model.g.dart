// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personnel_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonnelModel _$PersonnelModelFromJson(Map json) {
  return PersonnelModel(
    uuid: json['uuid'] as String,
    affiliation: AffiliationModel.fromJson(
        Map<String, dynamic>.from(json['affiliation'] as Map)),
    tracking: toTrackingRef(json['tracking']),
    operation: toOperationRef(json['operation']),
    status: _$enumDecodeNullable(_$PersonnelStatusEnumMap, json['status']),
    unit: toUnitRef(json['unit']),
    function: _$enumDecodeNullable(
        _$OperationalFunctionTypeEnumMap, json['function']),
  );
}

Map<String, dynamic> _$PersonnelModelToJson(PersonnelModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('status', _$PersonnelStatusEnumMap[instance.status]);
  writeNotNull('function', _$OperationalFunctionTypeEnumMap[instance.function]);
  val['affiliation'] = instance.affiliation.toJson();
  writeNotNull('unit', instance.unit?.toJson());
  writeNotNull('operation', instance.operation?.toJson());
  val['tracking'] = instance.tracking.toJson();
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
