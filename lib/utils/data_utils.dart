import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:collection';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/BaseMap.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/devices_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/widgets.dart';

import 'package:intl/intl.dart';
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
  if (point == null) return empty;
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

String formatDuration(Duration delta, {bool approx = true, String defaultValue = "-", bool withUnits = true}) {
  if (delta == null) return defaultValue;
  return delta.inHours > 99
      ? "${delta.inDays}${withUnits ? (delta.inDays > 1 ? " dager" : " dag") : ""}"
      : delta.inHours > 0
          ? "${delta.inHours}${withUnits ? (delta.inHours > 1 ? " timer" : " time") : ""}"
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

Point toPoint(LatLng point, {PointType type}) {
  return Point.now(
    point?.latitude ?? 0,
    point?.longitude ?? 0,
    type: type,
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

Duration asEffort(List<Point> history) => history?.isNotEmpty == true
    ? history.last.timestamp.difference(
        history.first.timestamp,
      )
    : Duration.zero;

emptyAsNull(value) => value is String
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

String toCallsign(String prefix, int number) {
  // TODO: Use number plan in fleet map (units use range 21 - 89, except all 'x0' numbers)
  final suffix = "${_callsignFormat.format(number % 10 == 0 ? ++number : number)}";
  return "$prefix ${suffix.substring(0, 1)}-${suffix.substring(1, 2)}";
}

T readState<T>(BuildContext context, String identifier, {T defaultValue}) =>
    PageStorage.of(context)?.readState(context, identifier: identifier) ?? defaultValue;

T writeState<T>(BuildContext context, String identifier, T value) {
  PageStorage.of(context)?.writeState(context, value, identifier: identifier);
  return value;
}

Future<PageStorageBucket> readAppState(PageStorageBucket bucket, {BuildContext context}) async {
  final json = readFromFile(await getApplicationDocumentsDirectory(), "app_state.json");
  if (json != null) {
    bucket.writeState(context, json[RouteWriter.NAME], identifier: RouteWriter.NAME);
    bucket.writeState(context, json[UnitsPageState.FILTER], identifier: UnitsPageState.FILTER);
    bucket.writeState(context, json[IncidentMapState.FILTER], identifier: IncidentMapState.FILTER);
    bucket.writeState(context, json[DevicesPageState.FILTER], identifier: DevicesPageState.FILTER);
    bucket.writeState(
      context,
      json[IncidentMapState.BASE_MAP] is Map<String, dynamic>
          ? BaseMap.fromJson(json[IncidentMapState.BASE_MAP])
          : Defaults.baseMap,
      identifier: IncidentMapState.BASE_MAP,
    );
  }
  return bucket;
}

Map<String, dynamic> readFromFile(Directory dir, String fileName) {
  var values;
  File file = new File(dir.path + "/" + fileName);
  if (file.existsSync()) {
    values = json.decode(file.readAsStringSync());
  }
  return values;
}

Future<void> writeAppState(PageStorageBucket bucket, {BuildContext context}) async {
  final json = {
    RouteWriter.NAME: bucket.readState(context, identifier: RouteWriter.NAME),
    UnitsPageState.FILTER: bucket.readState(context, identifier: UnitsPageState.FILTER),
    IncidentMapState.FILTER: bucket.readState(context, identifier: IncidentMapState.FILTER),
    DevicesPageState.FILTER: bucket.readState(context, identifier: DevicesPageState.FILTER),
    IncidentMapState.BASE_MAP: bucket.readState(context, identifier: IncidentMapState.BASE_MAP),
  };
  writeToFile(json, await getApplicationDocumentsDirectory(), "app_state.json");
}

void writeToFile(Map<String, dynamic> content, Directory dir, String fileName) {
  File file = new File(dir.path + "/" + fileName);
  if (!file.existsSync()) {
    file.createSync();
  }
  file.writeAsStringSync(json.encode(content));
}

class Pair<L, R> {
  final L left;
  final R right;
  Pair._(this.left, this.right);

  factory Pair.of(L left, R right) => Pair._(left, right);
}

extension MapX on Map {
  /// Check if map contains data at given path
  bool hasPath(String ref) => elementAt(ref) != null;

  /// Get element with given reference on format '/name1/name2/name3'
  /// equivalent to map['name1']['name2']['name3'].
  ///
  /// Returns [null] if not found
  T elementAt<T>(String path) {
    final parts = path.split('/');
    dynamic found = parts.skip(parts.first.isEmpty ? 1 : 0).fold(this, (parent, name) {
      if (parent is Map<String, dynamic>) {
        if (parent.containsKey(name)) {
          return parent[name];
        }
      }
      final element = (parent ?? {});
      return element is Map ? element[name] : element is List && element.isNotEmpty ? element[int.parse(name)] : null;
    });
    return found as T;
  }
}
