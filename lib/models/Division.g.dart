// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Division.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Division _$DivisionFromJson(Map<String, dynamic> json) {
  return Division(
      name: json['name'] as String,
      departments: (json['departments'] as Map<String, dynamic>)?.map(
        (k, e) => MapEntry(k, e as String),
      ));
}

Map<String, dynamic> _$DivisionToJson(Division instance) => <String, dynamic>{
      'name': instance.name,
      'departments': instance.departments
    };
