// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Affiliation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Affiliation _$AffiliationFromJson(Map json) {
  return Affiliation(
    org: json['org'] == null
        ? null
        : AggregateRef.fromJson((json['org'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    div: json['div'] == null
        ? null
        : AggregateRef.fromJson((json['div'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    dep: json['dep'] == null
        ? null
        : AggregateRef.fromJson((json['dep'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
  );
}

Map<String, dynamic> _$AffiliationToJson(Affiliation instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('org', instance.org?.toJson());
  writeNotNull('div', instance.div?.toJson());
  writeNotNull('dep', instance.dep?.toJson());
  return val;
}
