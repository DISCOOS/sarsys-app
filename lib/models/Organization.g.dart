// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organization _$OrganizationFromJson(Map<String, dynamic> json) {
  return Organization(
      name: json['name'] as String,
      alias: json['alias'] as String,
      pattern: json['pattern'] as String,
      functions: (json['functions'] as Map<String, dynamic>)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      divisions: (json['divisions'] as Map<String, dynamic>)?.map(
        (k, e) => MapEntry(k, e == null ? null : Division.fromJson(e as Map<String, dynamic>)),
      ),
      talkGroups: json['talk_groups'] == null
          ? null
          : const FleetMapTalkGroupConverter().fromJson(json['talk_groups'] as Map<String, dynamic>));
}

Map<String, dynamic> _$OrganizationToJson(Organization instance) => <String, dynamic>{
      'name': instance.name,
      'alias': instance.alias,
      'pattern': instance.pattern,
      'functions': instance.functions,
      'divisions': instance.divisions?.map((k, e) => MapEntry(k, e?.toJson())),
      'talk_groups': instance.talkGroups == null ? null : const FleetMapTalkGroupConverter().toJson(instance.talkGroups)
    };
