// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Personnel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Personnel _$PersonnelFromJson(Map json) {
  return Personnel(
    uuid: json['uuid'] as String,
    userId: json['userId'] as String,
    status: _$enumDecodeNullable(_$PersonnelStatusEnumMap, json['status']),
    fname: json['fname'] as String,
    lname: json['lname'] as String,
    phone: json['phone'] as String,
    affiliation: json['affiliation'] == null
        ? null
        : Affiliation.fromJson((json['affiliation'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    function:
        _$enumDecodeNullable(_$OperationalFunctionEnumMap, json['function']),
    unit: toUnitRef(json['unit']),
    tracking: toTrackingRef(json['tracking']),
  );
}

Map<String, dynamic> _$PersonnelToJson(Personnel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
    'userId': instance.userId,
    'status': _$PersonnelStatusEnumMap[instance.status],
    'fname': instance.fname,
    'lname': instance.lname,
    'phone': instance.phone,
    'affiliation': instance.affiliation?.toJson(),
    'function': _$OperationalFunctionEnumMap[instance.function],
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('unit', instance.unit?.toJson());
  writeNotNull('tracking', instance.tracking?.toJson());
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
  PersonnelStatus.Mobilized: 'Mobilized',
  PersonnelStatus.OnScene: 'OnScene',
  PersonnelStatus.Retired: 'Retired',
};

const _$OperationalFunctionEnumMap = {
  OperationalFunction.Commander: 'Commander',
  OperationalFunction.UnitLeader: 'UnitLeader',
  OperationalFunction.Personnel: 'Personnel',
};
