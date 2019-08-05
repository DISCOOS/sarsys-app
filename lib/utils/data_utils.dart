import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:latlong/latlong.dart';

String enumName(Object o) => o.toString().split('.').last;

String toDD(Point point, {String prefix = "DD", String empty = "Velg"}) {
  if (point == null) return empty;
  return ("$prefix ${CoordinateFormat.toDD(ProjCoordinate.from2D(point.lon, point.lat))}").trim();
}

String toDDM(Point point, {String prefix = "DDM", String empty = "Velg"}) {
  if (point == null) return empty;
  return ("$prefix ${CoordinateFormat.toDDM(ProjCoordinate.from2D(point.lon, point.lat))}").trim();
}

/// TODO: Make UTM zone and northing configurable
final _utmProj = TransverseMercatorProjection.utm(32, false);
String toUTM(Point point, {String prefix = "UTM", String empty = "Velg"}) {
  if (point == null) return empty;
  var src = ProjCoordinate.from2D(point.lon, point.lat);
  var dst = _utmProj.project(src);
  return ("$prefix ${CoordinateFormat.toUTM(dst)}").trim();
}

String formatSince(DateTime timestamp) {
  if (timestamp == null) return "-";
  Duration delta = DateTime.now().difference(timestamp);
  return delta.inHours > 99
      ? "${delta.inDays}d"
      : delta.inHours > 0
          ? "${delta.inHours} h"
          : delta.inMinutes > 0 ? "${delta.inMinutes} min" : "${delta.inSeconds} sec";
}

LatLng toLatLng(Point point) {
  return LatLng(point?.lat, point?.lon);
}

Point toPoint(LatLng point) {
  return Point.now(point?.latitude, point?.longitude);
}
