import 'package:SarSys/models/TalkGroup.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

class LatLngConverter implements JsonConverter<LatLng, Map<String, dynamic>> {
  const LatLngConverter();

  @override
  LatLng fromJson(Map<String, dynamic> json) => LatLng(
        json['lat'] as double,
        json['lon'] as double,
      );

  @override
  Map<String, dynamic> toJson(LatLng point) => {
        "lat": point.latitude,
        "lon": point.longitude,
      };
}

class LatLngBoundsConverter implements JsonConverter<LatLngBounds, Map<String, dynamic>> {
  const LatLngBoundsConverter();

  @override
  LatLngBounds fromJson(Map<String, dynamic> json) => json != null
      ? LatLngBounds(
          LatLngConverter().fromJson(json['ne']),
          LatLngConverter().fromJson(json['sw']),
        )
      : null;

  @override
  Map<String, dynamic> toJson(LatLngBounds bounds) => bounds != null
      ? {
          "ne": LatLngConverter().toJson(bounds.northEast),
          "sw": LatLngConverter().toJson(bounds.southWest),
        }
      : null;

  static LatLngBounds to(LatLng sw, LatLng ne) {
    return LatLngBounds(sw, ne);
  }
}

class FleetMapTalkGroupConverter implements JsonConverter<Map<String, List<TalkGroup>>, Map<String, dynamic>> {
  const FleetMapTalkGroupConverter();

  @override
  Map<String, List<TalkGroup>> fromJson(Map<String, dynamic> json) {
    Map<String, List<TalkGroup>> map = json.map(
      (key, list) => MapEntry(
        key,
        (list as List<dynamic>).map((name) => to(name as String)).toList(),
      ),
    );
    return map;
  }

  @override
  Map<String, dynamic> toJson(Map<String, List<TalkGroup>> items) {
    return items.map((key, list) => MapEntry(key, list.map((tg) => tg.name).toList()));
  }

  static TalkGroup to(String name) {
    return TalkGroup(name: name, type: TalkGroupType.Tetra);
  }

  static List<TalkGroup> toList(List<String> names) {
    return names.map((name) => to(name)).toList();
  }
}
