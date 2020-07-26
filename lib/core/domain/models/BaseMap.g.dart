// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'BaseMap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseMap _$BaseMapFromJson(Map json) {
  return BaseMap(
    url: json['url'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    maxZoom: (json['maxZoom'] as num)?.toDouble(),
    minZoom: (json['minZoom'] as num)?.toDouble(),
    attribution: json['attribution'] as String,
    bounds: const LatLngBoundsConverter()
        .fromJson(json['bounds'] as Map<String, dynamic>),
    offline: json['offline'] as bool,
    previewFile: json['previewFile'] as String,
    tms: json['tms'] as bool,
    subdomains: (json['subdomains'] as List)?.map((e) => e as String)?.toList(),
  );
}

Map<String, dynamic> _$BaseMapToJson(BaseMap instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('description', instance.description);
  writeNotNull('url', instance.url);
  writeNotNull('maxZoom', instance.maxZoom);
  writeNotNull('minZoom', instance.minZoom);
  writeNotNull('attribution', instance.attribution);
  writeNotNull('offline', instance.offline);
  writeNotNull('tms', instance.tms);
  writeNotNull('previewFile', instance.previewFile);
  writeNotNull('subdomains', instance.subdomains);
  writeNotNull('bounds', const LatLngBoundsConverter().toJson(instance.bounds));
  return val;
}
