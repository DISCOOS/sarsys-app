// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Personnel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Personnel _$PersonnelFromJson(Map<String, dynamic> json) {
  return Personnel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      status: _$enumDecodeNullable(_$PersonnelStatusEnumMap, json['status']),
      fname: json['fname'] as String,
      lname: json['lname'] as String,
      phone: json['phone'] as String,
      affiliation: json['affiliation'] == null
          ? null
          : Affiliation.fromJson(json['affiliation'] as Map<String, dynamic>),
      function:
          _$enumDecodeNullable(_$OperationalFunctionEnumMap, json['function']),
      tracking: json['tracking'] as String);
}

Map<String, dynamic> _$PersonnelToJson(Personnel instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'status': _$PersonnelStatusEnumMap[instance.status],
      'fname': instance.fname,
      'lname': instance.lname,
      'phone': instance.phone,
      'affiliation': instance.affiliation?.toJson(),
      'function': _$OperationalFunctionEnumMap[instance.function],
      'tracking': instance.tracking
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$PersonnelStatusEnumMap = <PersonnelStatus, dynamic>{
  PersonnelStatus.Mobilized: 'Mobilized',
  PersonnelStatus.OnScene: 'OnScene',
  PersonnelStatus.Retired: 'Retired'
};

const _$OperationalFunctionEnumMap = <OperationalFunction, dynamic>{
  OperationalFunction.Commander: 'Commander',
  OperationalFunction.UnitLeader: 'UnitLeader',
  OperationalFunction.Personnel: 'Personnel'
};
