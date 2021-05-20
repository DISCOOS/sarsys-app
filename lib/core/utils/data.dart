import 'dart:math';
import 'dart:collection';

import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

/// Type helper class
Type typeOf<T>() => T;

String enumName(Object o) => o.toString().split('.').last;

String toDD(Point point, {String prefix = "DD", String empty = "Velg"}) {
  if (point == null) return empty;
  return ("$prefix ${CoordinateFormat.toDD(ProjCoordinate.from2D(point.lon, point.lat))}").trim();
}

String toDDM(Point point, {String prefix = "DDM", String empty = "Velg"}) {
  if (point == null) return empty;
  return ("$prefix ${CoordinateFormat.toDDM(ProjCoordinate.from2D(point.lon, point.lat))}").trim();
}

final _utmProjs = {"32.false": TransverseMercatorProjection.utm(32, false)};
TransverseMercatorProjection toUTMProj({
  int zone = 32,
  bool isSouth = false,
}) {
  return _utmProjs.putIfAbsent("$zone.$isSouth", () => TransverseMercatorProjection.utm(zone, isSouth));
}

String toUTM(
  Point point, {
  int zone = 32,
  bool isSouth = false,
  String prefix = "UTM",
  String empty = "Velg",
}) {
  if (point?.isNotEmpty != true) return empty;
  var src = ProjCoordinate.from2D(point.lon, point.lat);
  var proj = toUTMProj(zone: zone, isSouth: isSouth);
  var dst = proj.project(src);
  var band = TransverseMercatorProjection.toBand(point.lat);
  return ("$prefix ${CoordinateFormat.toUTM(dst, zone: zone, band: band)}").trim();
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

String formatDuration(
  Duration delta, {
  bool approx = true,
  String defaultValue = "-",
  bool withUnits = true,
  bool withMillis = false,
}) {
  if (delta == null) return defaultValue;
  return delta.inHours > 99
      ? "${delta.inDays}${withUnits ? (delta.inDays > 1 ? " dager" : " dag") : ""}"
      : delta.inHours > 0
          ? "${delta.inHours}${withUnits ? (delta.inHours > 1 ? " timer" : " time") : ""}"
          : delta.inMinutes > 0
              ? "${delta.inMinutes}${withUnits ? " min" : ""}"
              : delta.inSeconds > 0
                  ? "${delta.inSeconds}${withUnits ? " sek" : ""}"
                  : !withMillis && approx
                      ? "~1${withUnits ? " sek" : ""}"
                      : "${delta.inMilliseconds}${withUnits ? " ms" : ""}";
}

String formatDistance(double distance) {
  if (distance == null) return "-";
  return distance > 1000 ? "${(distance / 1000).toStringAsFixed(1)} km" : "${distance.round()} m";
}

LatLng toLatLng(Point point) {
  return LatLng(point?.lat ?? 0.0, point?.lon ?? 0.0);
}

Point toPoint(LatLng point) {
  return Point.fromCoords(
    lat: point?.latitude ?? 0,
    lon: point?.longitude ?? 0,
  );
}

Position toPosition(LatLng point) {
  return Position.now(
    lat: point?.latitude ?? 0,
    lon: point?.longitude ?? 0,
    source: PositionSource.manual,
  );
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

bool isEmptyOrNull(value) => emptyAsNull(value) == null;

T emptyAsNull<T>(T value) => value is String
    ? (value.isNotEmpty == true ? value : null)
    : (value is Iterable ? (value.isNotEmpty == true ? value : null) : value);

List<String> asUnitTemplates(String prefix, int count) {
  final types = UnitType.values.where(
    (type) {
      final name = translateUnitType(type).toLowerCase();
      final match =
          prefix.length >= name.length ? prefix.substring(0, min(name.length, prefix.length))?.trim() : prefix;
      return name.startsWith(match.toLowerCase());
    },
  );
  final templates = types.fold<List<String>>(
    <String>[],
    (templates, type) {
      final name = translateUnitType(type);
      final suffix = prefix.substring(min(name.length, prefix.length))?.trim();
      final offset = (suffix is num) ? int.parse(suffix) : 1;
      templates.addAll(
        List<String>.generate(count, (index) => "$name ${index + offset}"),
      );
      return templates;
    },
  )?.toList();
  return templates ?? <String>[];
}

final _callsignFormat = NumberFormat("00")..maximumFractionDigits = 0;

String toCallsign(UnitType type, String prefix, int number) {
  var base;
  switch (type) {
    case UnitType.k9:
      base = 10;
      break;
    case UnitType.team:
      base = 20;
      break;
    case UnitType.boat:
    case UnitType.vehicle:
    case UnitType.snowmobile:
    case UnitType.atv:
      base = 50;
      break;
    case UnitType.commandpost:
      base = 90;
      break;
    case UnitType.other:
      break;
  }
  // TODO: Use number plan in fleet map (units use range 21 - 89, except all 'x0' numbers)
  final digits = base + (number % 10 == 0 ? ++number : number);
  final suffix = "${_callsignFormat.format(digits)}";
  return "${prefix ?? enumName(type)} ${suffix.substring(0, 1)}-${suffix.substring(1, 2)}";
}

class Pair<L, R> {
  final L left;
  final R right;
  Pair._(this.left, this.right);

  factory Pair.of(L left, R right) => Pair._(left, right);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pair && runtimeType == other.runtimeType && left == other.left && right == other.right;

  @override
  int get hashCode => left.hashCode ^ right.hashCode;

  @override
  String toString() {
    return '{${left.runtimeType}, ${right.runtimeType}}';
  }
}
