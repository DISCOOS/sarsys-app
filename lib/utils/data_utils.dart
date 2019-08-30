import 'dart:collection';

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
      : delta.inHours > 0 ? "${delta.inHours}h" : delta.inMinutes > 0 ? "${delta.inMinutes}m" : "${delta.inSeconds}s";
}

String formatDistance(double distance) {
  if (distance == null) return "-";
  return distance > 10000 ? "${(distance / 1000).toStringAsFixed(3)} km" : "${distance.round()} m";
}

LatLng toLatLng(Point point) {
  return LatLng(point?.lat, point?.lon);
}

Point toPoint(LatLng point) {
  return Point.now(point?.latitude, point?.longitude);
}

List<T> sortList<T>(List<T> data, [int compare(T a, T b)]) {
  data.sort(compare);
  return data;
}

/// Sort map on keys
Map<K, V> sortMapKeys<K, V, T>(Map<K, V> map, [int compare(K a, K b)]) {
  final keys = map.keys.toList(growable: false);
  if (compare == null) compare = (K a, K b) => "$a".compareTo("$b");
  keys.sort((k1, k2) => compare(k1, k2));
  LinkedHashMap<K, V> sortedMap = new LinkedHashMap();
  keys.forEach((k1) {
    sortedMap[k1] = map[k1];
  });
  return sortedMap;
}

/// Sort map on values.
Map<K, V> sortMapValues<K, V, T>(Map<K, V> map, [T mapper(V value), int compare(T a, T b)]) {
  final keys = map.keys.toList(growable: false);
  if (mapper == null) mapper = (V value) => value as T;
  if (compare == null) compare = (T a, T b) => "$a".compareTo("$b");
  keys.sort((k1, k2) => compare(mapper(map[k1]), mapper(map[k2])));
  LinkedHashMap<K, V> sortedMap = new LinkedHashMap();
  keys.forEach((k1) {
    sortedMap[k1] = map[k1];
  });
  return sortedMap;
}
