import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

import 'AggregateRef.dart';
import 'Coordinates.dart';
import '../features/operation/domain/entities/Incident.dart';
import 'Tracking.dart';
import '../features/unit/domain/entities/Unit.dart';

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

class FleetMapTalkGroupConverter implements JsonConverter<List<TalkGroup>, List<dynamic>> {
  const FleetMapTalkGroupConverter();

  @override
  List<TalkGroup> fromJson(List<dynamic> list) {
    var id = 0;
    final map = list.map(
      (name) => to('${id++}', name as String),
    );
    return map.toList();
  }

  @override
  List<dynamic> toJson(List<TalkGroup> items) {
    return items.map((tg) => tg.name).toList();
  }

  static TalkGroup to(String id, String name) {
    return TalkGroup(
      id: id,
      name: name,
      type: TalkGroupType.tetra,
    );
  }

  static List<TalkGroup> toList(List<String> names) {
    var id = 0;
    return names.map((name) => to('${id++}', name)).toList();
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
