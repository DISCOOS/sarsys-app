// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Division.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Division _$DivisionFromJson(Map json) {
  return Division(
    name: json['name'] as String,
    departments: (json['departments'] as Map)?.map(
      (k, e) => MapEntry(k as String, e as String),
    ),
  );
}

Map<String, dynamic> _$DivisionToJson(Division instance) => <String, dynamic>{
      'name': instance.name,
      'departments': instance.departments,
    };
