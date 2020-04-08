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
    pattern: json['pattern'] as String,
    idpHints: (json['idpHints'] as List)?.map((e) => e as String)?.toList(),
    functions: (json['functions'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
    divisions: (json['divisions'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(
          k, e == null ? null : Division.fromJson(e as Map<String, dynamic>)),
    ),
    talkGroups: const FleetMapTalkGroupConverter()
        .fromJson(json['talk_groups'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$OrganizationToJson(Organization instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'alias': instance.alias,
      'pattern': instance.pattern,
      'idpHints': instance.idpHints,
      'functions': instance.functions,
      'divisions': instance.divisions?.map((k, e) => MapEntry(k, e?.toJson())),
      'talk_groups':
          const FleetMapTalkGroupConverter().toJson(instance.talkGroups),
    };
