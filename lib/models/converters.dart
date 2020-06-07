import 'package:SarSys/models/TalkGroup.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

import 'AggregateRef.dart';
import 'Coordinates.dart';
import '../features/incident/domain/entities/Incident.dart';
import 'Tracking.dart';
import 'Unit.dart';

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

AggregateRef<Unit> toUnitRef(dynamic json) {
  return json != null ? AggregateRef<Unit>.fromJson(Map<String, dynamic>.from(json)) : null;
}

AggregateRef<Incident> toIncidentRef(dynamic json) {
  return json != null ? AggregateRef<Incident>.fromJson(Map<String, dynamic>.from(json)) : null;
}

AggregateRef<Tracking> toTrackingRef(dynamic json) {
  return json != null ? AggregateRef<Tracking>.fromJson(Map<String, dynamic>.from(json)) : null;
}

double latFromJson(Object json) => _toDouble(json, 0);
double lonFromJson(Object json) => _toDouble(json, 1);
double altFromJson(Object json) => _toDouble(json, 2);

double _toDouble(Object json, int index) {
  if (json is List) {
    if (index < json.length) {
      var value = json[index];
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.parse(value);
      }
    }
  }
  return null;
}

Coordinates coordsFromJson(List json) => Coordinates.fromJson(json);
dynamic coordsToJson(Coordinates coords) => coords.toJson();
