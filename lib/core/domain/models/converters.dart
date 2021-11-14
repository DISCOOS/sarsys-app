

import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/features/mapping/domain/entities/Coordinates.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';

import 'AggregateRef.dart';

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

class LatLngBoundsConverter implements JsonConverter<LatLngBounds?, Map<String, dynamic>?> {
  const LatLngBoundsConverter();

  @override
  LatLngBounds? fromJson(Map<String, dynamic>? json) => json != null
      ? LatLngBounds(
          LatLngConverter().fromJson(json['ne']),
          LatLngConverter().fromJson(json['sw']),
        )
      : null;

  @override
  Map<String, dynamic>? toJson(LatLngBounds? bounds) => bounds != null
      ? {
          "ne": LatLngConverter().toJson(bounds.northEast!),
          "sw": LatLngConverter().toJson(bounds.southWest!),
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
      (name) => to('${id++}', name as String?),
    );
    return map.toList();
  }

  @override
  List<dynamic> toJson(List<TalkGroup> items) {
    return items.map((tg) => tg.name).toList();
  }

  static TalkGroup to(String id, String? name) {
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

AggregateRef<UnitModel> toUnitRef(dynamic json) => AggregateRef<UnitModel>.fromJson(json);
AggregateRef<Tracking> toTrackingRef(dynamic json) => AggregateRef<Tracking>.fromJson(json);
AggregateRef<PersonModel> toPersonRef(dynamic json) => AggregateRef<PersonModel>.fromJson(json);
AggregateRef<DivisionModel> toDivRef(dynamic json) => AggregateRef<DivisionModel>.fromJson(json);
AggregateRef<DepartmentModel> toDepRef(dynamic json) => AggregateRef<DepartmentModel>.fromJson(json);
AggregateRef<IncidentModel> toIncidentRef(dynamic json) => AggregateRef<IncidentModel>.fromJson(json);
AggregateRef<OperationModel> toOperationRef(dynamic json) => AggregateRef<OperationModel>.fromJson(json);
AggregateRef<OrganisationModel> toOrgRef(dynamic json) => AggregateRef<OrganisationModel>.fromJson(json);
AggregateRef<AffiliationModel> toAffiliationRef(dynamic json) => AggregateRef<AffiliationModel>.fromJson(json);

/// GeoJSON specifies longitude at index 0,
/// see https://tools.ietf.org/html/rfc7946#section-3.1.1
double? lonFromJson(Object? json) => _toDouble(json, 0);

/// GeoJSON specifies latitude at index 1,
/// see https://tools.ietf.org/html/rfc7946#section-3.1.1
double? latFromJson(Object? json) => _toDouble(json, 1);

/// GeoJSON specifies altitude at index 2,
/// see https://tools.ietf.org/html/rfc7946#section-3.1.1
double? altFromJson(Object? json) => _toDouble(json, 2);

double? _toDouble(Object? json, int index) {
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

Coordinates coordsFromJson(List? json) => Coordinates.fromJson(json);
dynamic coordsToJson(Coordinates coords) => coords.toJson();
