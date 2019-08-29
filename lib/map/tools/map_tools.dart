import 'dart:math' as math;

import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

typedef MatchCallback = Future Function(MapTool tool, Iterable matches);

class MapToolController {
  final List<MapTool> tools;
  final double tapTargetSize;
  final MatchCallback onMatch;

  MapToolController({
    @required this.tools,
    this.onMatch,
    this.tapTargetSize = 120.0,
  });

  void onTap(BuildContext context, LatLng point, double zoom, List<double> scales) {
    final size = MediaQuery.of(context).size;
    final tolerance = tapTargetSize / math.max(size.width, size.height);
    final distance = tolerance * ScaleBar.toDistance(scales, zoom);
    tools.firstWhere((tool) => tool.active && tool.onTap(context, point, distance, onMatch), orElse: () => null);
  }

  void onLongPress(BuildContext context, LatLng point, double zoom, List<double> scales) {
    final size = MediaQuery.of(context).size;
    final tolerance = tapTargetSize / math.max(size.width, size.height);
    final distance = tolerance * ScaleBar.toDistance(scales, zoom);
    tools.firstWhere((tool) => tool.active && tool.onLongPress(context, point, distance, onMatch), orElse: () => null);
  }
}

abstract class MapTool<T> {
  bool active;
  Iterable<T> targets;

  MapTool(this.active, this.targets);

  LatLng toPoint(T target);
  void doProcessTap(BuildContext context, List<T> matches);
  void doProcessLongPress(BuildContext context, List<T> matches);

  bool onTap(BuildContext context, LatLng point, double tolerance, MatchCallback onMatch) {
    return _match(context, point, tolerance, onMatch, doProcessTap);
  }

  bool onLongPress(BuildContext context, LatLng point, double tolerance, MatchCallback onMatch) {
    return _match(context, point, tolerance, onMatch, doProcessLongPress);
  }

  bool _match(
    BuildContext context,
    LatLng point,
    double tolerance,
    MatchCallback onMatch,
    void execute(BuildContext context, List<T> matches),
  ) {
    final matches = targets.where((target) => _within(point, toPoint(target), tolerance)).toList(growable: false);
    if (matches.isNotEmpty) execute(context, matches);
    if (onMatch != null) onMatch(this, matches);
    return matches.isNotEmpty;
  }

  bool _within(LatLng point, LatLng match, double tolerance) {
    return ProjMath.eucledianDistance(
          point.latitude,
          point.longitude,
          match.latitude,
          match.longitude,
        ) <
        tolerance;
  }
}
