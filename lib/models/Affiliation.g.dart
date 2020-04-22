// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Affiliation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Affiliation _$AffiliationFromJson(Map json) {
  return Affiliation(
    orgId: json['orgId'] as String,
    divId: json['divId'] as String,
    depId: json['depId'] as String,
  );
}

Map<String, dynamic> _$AffiliationToJson(Affiliation instance) =>
    <String, dynamic>{
      'orgId': instance.orgId,
      'divId': instance.divId,
      'depId': instance.depId,
    };
