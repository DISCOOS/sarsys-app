import 'package:SarSys/map/tools/map_tools.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class MeasureTool extends MapTool with MapEditable<Set<LatLng>> {
  @override
  Set<LatLng> target = {};

  MeasureTool() : super(false);

  void init() => changed(() => target..clear());
  void add(LatLng point) => changed(() => target.add(point));
  void remove() => changed(() => {if (target.isNotEmpty) target.remove(target.last)});

  @override
  bool onTap(BuildContext context, LatLng point, double tolerance, onMatch) {
    return true;
  }
}
