import 'dart:collection';
import 'dart:math';

import 'package:SarSys/models/Point.dart';
import 'package:SarSys/core/proj4d.dart';
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

String formatSince(DateTime timestamp, {bool approx = true, String defaultValue = "-", bool withUnits = true}) {
  if (timestamp == null) return defaultValue;
  return formatDuration(
    DateTime.now().difference(timestamp),
    approx: approx,
    defaultValue: defaultValue,
    withUnits: withUnits,
  );
}

String formatDuration(Duration delta, {bool approx = true, String defaultValue = "-", bool withUnits = true}) {
  if (delta == null) return defaultValue;
  return delta.inHours > 99
      ? "${delta.inDays}${withUnits ? " dager" : ""}"
      : delta.inHours > 0
          ? "${delta.inHours}${withUnits ? " timer" : ""}"
          : delta.inMinutes > 0
              ? "${delta.inMinutes}${withUnits ? " min" : ""}"
              : approx ? "~1${withUnits ? " min" : ""}" : "${delta.inSeconds}${withUnits ? " sek" : ""}";
}

String formatDistance(double distance) {
  if (distance == null) return "-";
  return distance > 1000 ? "${(distance / 1000).toStringAsFixed(1)} km" : "${distance.round()} m";
}

LatLng toLatLng(Point point) {
  return LatLng(point?.lat ?? 0.0, point?.lon ?? 0.0);
}

Point toPoint(LatLng point) {
  return Point.now(point?.latitude ?? 0, point?.longitude ?? 0);
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

double asSpeed(double distance, Duration effort) =>
    distance.isNaN == false && effort.inMicroseconds > 0.0 ? distance / effort.inSeconds : 0.0;

double asDistance(List<Point> history, {double distance = 0, int tail = 2}) {
  distance ??= 0;
  var offset = max(0, history.length - tail - 1);
  var i = offset + 1;
  history?.skip(offset)?.forEach((point) {
    i++;
    distance += i < history.length
        ? ProjMath.eucledianDistance(
            history[i]?.lat ?? point.lat,
            history[i]?.lon ?? point.lon,
            point.lat,
            point.lon,
          )
        : 0.0;
  });
  return distance;
}

Duration asEffort(List<Point> history) =>
    history.isNotEmpty ? history.last.timestamp.difference(history.first.timestamp) : Duration.zero;
