import 'package:SarSys/map/tools/map_tools.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class MeasureTool extends MapTool with MapEditable<List<LatLng>> {
  @override
  List<LatLng> target = [];

  MeasureTool() : super(false);

  void onInit(LatLng point) => changed(() => target
    ..clear()
    ..add(point));

  void onAdd(LatLng point) => changed(() => target.add(point));
  void clear() => changed(() => target.clear());

  @override
  bool onTap(BuildContext context, LatLng point, double tolerance, onMatch) {
    return true;
  }
}
