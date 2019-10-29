// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'BaseMap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseMap _$BaseMapFromJson(Map<String, dynamic> json) {
  return BaseMap(
      name: json['name'] as String,
      description: json['description'] as String,
      url: json['url'] as String,
      maxZoom: (json['maxZoom'] as num)?.toDouble(),
      minZoom: (json['minZoom'] as num)?.toDouble(),
      attribution: json['attribution'] as String,
      offline: json['offline'] as bool,
      previewFile: json['previewFile'] as String,
      tms: json['tms'] as bool,
      subdomains:
          (json['subdomains'] as List)?.map((e) => e as String)?.toList());
}

Map<String, dynamic> _$BaseMapToJson(BaseMap instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'url': instance.url,
      'maxZoom': instance.maxZoom,
      'minZoom': instance.minZoom,
      'attribution': instance.attribution,
      'offline': instance.offline,
      'previewFile': instance.previewFile,
      'tms': instance.tms,
      'subdomains': instance.subdomains
    };
