import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/proj4d.dart';
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
  final ActionCallback onMessage;

  UnitLayerOptions({
    @required this.bloc,
    this.size = 8.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.showTail = true,
    this.showRetired = false,
    this.onMessage,
  }) : super(rebuild: bloc.map((_) => null));
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
    final tracking = options.bloc.trackings;
    final units = sortMapValues<String, Unit, TrackingStatus>(
            options.bloc.units.asTrackingIds(exclude: options.showRetired ? [] : [TrackingStatus.closed]),
            (unit) => tracking[unit.tracking.uuid].status,
            (s1, s2) => s1.index - s2.index)
        .values
        .where((unit) => tracking[unit.tracking.uuid]?.position?.isNotEmpty == true)
        .where((unit) => options.showRetired || unit.status != UnitStatus.Retired)
        .where((unit) => bounds.contains(toLatLng(tracking[unit.tracking.uuid]?.position?.geometry)));
    return tracking.isEmpty
        ? Container()
        : Stack(
            overflow: Overflow.clip,
            children: [
              if (options.showTail)
                ...units
                    .map((unit) => _buildTrack(context, size, options, map, unit, tracking[unit.tracking.uuid]))
                    .toList(),
              if (options.showLabels)
                ...units
                    .map((unit) =>
                        _buildLabel(context, options, map, unit, tracking[unit.tracking.uuid].position?.geometry))
                    .toList(),
              ...units.map((unit) => _buildPoint(context, options, map, unit, tracking[unit.tracking.uuid])).toList(),
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
    var offsets = tracking.history.reversed.take(10).map((position) {
      var pos = map.project(toLatLng(position.geometry));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = toPositionStatusColor(tracking.position);

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
    var point = tracking.position?.geometry;
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x, pos.y, tracking.position);

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
          centerColor: toUnitStatusColor(unit.status),
          color: toPositionStatusColor(tracking.position),
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

double _toPixelRadius(MapState map, double size, double x, double y, Position position) {
  if (position == null) return 0;
  var pixelRadius = size;
  if (position.acc != null && position.acc > 0.0) {
    var coords = ProjMath.calculateEndingGlobalCoordinates(
      position.lat,
      position.lon,
      45.0,
      position.acc,
    );
    var pos = map.project(LatLng(coords.y, coords.x));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
  }
  return pixelRadius;
}
