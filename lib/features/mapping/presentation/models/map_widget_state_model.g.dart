// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_widget_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapWidgetStateModel _$MapWidgetStateModelFromJson(Map json) {
  return MapWidgetStateModel(
    center: MapWidgetStateModel._toLatLng(json['center'] as Map<String, dynamic>),
    zoom: (json['zoom'] as num)?.toDouble(),
    baseMap: json['baseMap'] == null
        ? null
        : BaseMap.fromJson((json['baseMap'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    filters: (json['filters'] as List)?.map((e) => e as String)?.toList(),
    ouuid: json['ouuid'] as String,
    following: json['following'] as bool,
  );
}

Map<String, dynamic> _$MapWidgetStateModelToJson(MapWidgetStateModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('zoom', instance.zoom);
  writeNotNull('center', MapWidgetStateModel._toJson(instance.center));
  writeNotNull('baseMap', instance.baseMap?.toJson());
  writeNotNull('filters', instance.filters);
  writeNotNull('following', instance.following);
  writeNotNull('ouuid', instance.ouuid);
  return val;
}
