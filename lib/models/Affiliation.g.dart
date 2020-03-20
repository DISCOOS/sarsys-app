// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Affiliation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Affiliation _$AffiliationFromJson(Map<String, dynamic> json) {
  return Affiliation(
    organization: json['organization'] as String,
    division: json['division'] as String,
    department: json['department'] as String,
  );
}

Map<String, dynamic> _$AffiliationToJson(Affiliation instance) =>
    <String, dynamic>{
      'organization': instance.organization,
      'division': instance.division,
      'department': instance.department,
    };
