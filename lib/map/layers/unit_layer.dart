import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:latlong/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class UnitLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  bool showTail;
  bool showRetired;
  final TrackingBloc bloc;
  final MessageCallback onMessage;

  UnitLayerOptions({
    @required this.bloc,
    this.size = 8.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.showTail = true,
    this.showRetired = false,
    this.onMessage,
  }) : super(rebuild: bloc.state.map((_) => null));
}

class UnitLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is UnitLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as UnitLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, UnitLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final tracks = options.bloc.tracks;
    final units = sortMapValues<String, Unit, TrackingStatus>(
            options.bloc.getTrackedUnits(exclude: options.showRetired ? [] : [TrackingStatus.Closed]),
            (unit) => tracks[unit.tracking].status,
            (s1, s2) => s1.index - s2.index)
        .values
        .where((unit) => options.showRetired || unit.status != UnitStatus.Retired)
        .where((unit) => bounds.contains(toLatLng(tracks[unit.tracking].location)));
    return options.bloc.isEmpty
        ? Container()
        : Stack(
            overflow: Overflow.visible,
            children: [
              if (options.showTail)
                ...units.map((unit) => _buildTrack(context, size, options, map, unit, tracks[unit.tracking])).toList(),
              if (options.showLabels)
                ...units
                    .map((unit) => _buildLabel(context, options, map, unit, tracks[unit.tracking].location))
                    .toList(),
              ...units.map((unit) => _buildPoint(context, options, map, unit, tracks[unit.tracking])).toList(),
            ],
          );
  }

  _buildTrack(
    BuildContext context,
    Size size,
    UnitLayerOptions options,
    MapState map,
    Unit unit,
    Tracking tracking,
  ) {
    var offsets = tracking.history.reversed.take(10).map((point) {
      var pos = map.project(toLatLng(point));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = toPointStatusColor(context, tracking.location);

    return CustomPaint(
      painter: LineStringPainter(
        offsets: offsets,
        color: color,
        borderColor: color,
        opacity: options.opacity,
      ),
      size: size,
    );
  }

  Widget _buildPoint(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Tracking tracking) {
    var size = options.size;
    var location = tracking.location;
    var pos = map.project(toLatLng(location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x, pos.y, location);

    return Positioned(
      top: pos.y,
      left: pos.x,
      width: pixelRadius,
      height: pixelRadius,
      child: CustomPaint(
        painter: PointPainter(
          size: size,
          opacity: options.opacity,
          outer: pixelRadius,
          color: toPointStatusColor(context, tracking.location),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Point point) {
    var size = options.size;
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      top: pos.y + size,
      left: pos.x,
      child: CustomPaint(
        painter: LabelPainter(unit.name, top: size),
        size: Size(size, size),
      ),
    );
  }
}

double _toPixelRadius(MapState map, double size, double x, double y, Point point) {
  if (point == null) return 0;
  var pixelRadius = size;
  if (point.acc != null && point.acc > 0.0) {
    var coords = ProjMath.calculateEndingGlobalCoordinates(
      point.lat,
      point.lon,
      45.0,
      point.acc,
    );
    var pos = map.project(LatLng(coords.y, coords.x));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
  }
  return pixelRadius;
}
