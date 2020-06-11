// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organization _$OrganizationFromJson(Map json) {
  return Organization(
    id: json['id'] as String,
    name: json['name'] as String,
    alias: json['alias'] as String,
    pattern: json['pattern'] as String,
    idpHints: (json['idpHints'] as List)?.map((e) => e as String)?.toList(),
    functions: (json['functions'] as Map)?.map(
      (k, e) => MapEntry(k as String, e as String),
    ),
    divisions: (json['divisions'] as Map)?.map(
      (k, e) => MapEntry(
          k as String,
          e == null
              ? null
              : Division.fromJson((e as Map)?.map(
                  (k, e) => MapEntry(k as String, e),
                ))),
    ),
    talkGroups: const FleetMapTalkGroupConverter()
        .fromJson(json['talk_groups'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$OrganizationToJson(Organization instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('name', instance.name);
  writeNotNull('alias', instance.alias);
  writeNotNull('pattern', instance.pattern);
  writeNotNull('idpHints', instance.idpHints);
  writeNotNull('functions', instance.functions);
  writeNotNull(
      'divisions', instance.divisions?.map((k, e) => MapEntry(k, e?.toJson())));
  writeNotNull('talk_groups',
      const FleetMapTalkGroupConverter().toJson(instance.talkGroups));
  return val;
}
