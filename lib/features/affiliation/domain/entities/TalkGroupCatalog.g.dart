// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TalkGroupCatalog.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TalkGroupCatalog _$TalkGroupCatalogFromJson(Map json) {
  return TalkGroupCatalog(
    name: json['name'] as String,
    groups: const FleetMapTalkGroupConverter().fromJson(json['groups'] as List),
  );
}

Map<String, dynamic> _$TalkGroupCatalogToJson(TalkGroupCatalog instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull(
      'groups', const FleetMapTalkGroupConverter().toJson(instance.groups));
  return val;
}
