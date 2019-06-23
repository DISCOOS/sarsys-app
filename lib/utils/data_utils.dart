import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:latlong/latlong.dart';

String enumName(Object o) => o.toString().split('.').last;
String enumDescription(Object o) {
  if (o is IncidentType) {
    switch (o) {
      case IncidentType.Lost:
        return "Savnet person";
      case IncidentType.Distress:
        return "Nødstedt";
      case IncidentType.Other:
        return "Annet";
    }
  }
  return "Ukjent";
}

String toDD(Point point) {
  return CoordinateFormat.toDD(ProjCoordinate.from2D(point.lon, point.lat));
}

/// TODO: Make UTM zone and northing configurable
final _utmProj = TransverseMercatorProjection.utm(32, false);
String toUTM(Point point, [String empty = "Velg"]) {
  if (point == null) return empty;
  var src = ProjCoordinate.from2D(point.lon, point.lat);
  var dst = _utmProj.project(src);
  return CoordinateFormat.toUTM(dst);
}

String formatSince(DateTime timestamp) {
  if (timestamp == null) return "-";
  Duration delta = DateTime.now().difference(timestamp);
  return delta.inHours > 99 ? "${delta.inDays}d" : delta.inHours > 0 ? "${delta.inHours}h" : "${delta.inSeconds}h";
}

LatLng toLatLng(Point point) {
  return LatLng(point?.lat, point?.lon);
}
