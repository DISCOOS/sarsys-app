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

Map<String, dynamic> _$AffiliationToJson(Affiliation instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('orgId', instance.orgId);
  writeNotNull('divId', instance.divId);
  writeNotNull('depId', instance.depId);
  return val;
}
