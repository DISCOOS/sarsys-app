// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_widget_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapWidgetStateModel _$MapWidgetStateModelFromJson(Map json) {
  return MapWidgetStateModel(
    center:
        MapWidgetStateModel._toLatLng(json['center'] as Map<String, dynamic>),
    zoom: (json['zoom'] as num)?.toDouble(),
    baseMap: json['baseMap'] == null
        ? null
        : BaseMap.fromJson((json['baseMap'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    filters: (json['filters'] as List)?.map((e) => e as String)?.toList(),
    incident: json['incident'] as String,
    following: json['following'] as bool,
  );
}

Map<String, dynamic> _$MapWidgetStateModelToJson(
        MapWidgetStateModel instance) =>
    <String, dynamic>{
      'zoom': instance.zoom,
      'center': MapWidgetStateModel._toJson(instance.center),
      'baseMap': instance.baseMap?.toJson(),
      'filters': instance.filters,
      'following': instance.following,
      'incident': instance.incident,
    };
