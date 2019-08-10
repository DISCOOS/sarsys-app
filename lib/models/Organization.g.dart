// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organization _$OrganizationFromJson(Map<String, dynamic> json) {
  return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      alias: json['alias'] as String,
      pattern: json['pattern'] as String);
}

Map<String, dynamic> _$OrganizationToJson(Organization instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'alias': instance.alias,
      'pattern': instance.pattern
    };
