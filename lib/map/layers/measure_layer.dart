import 'dart:async';

import 'package:SarSys/map/tools/measure_tool.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

import '../painters.dart';

class MeasureLayerOptions extends LayerOptions {
  double size;
  double opacity;
  MeasureTool tool;
  final ActionCallback onMessage;

  MeasureLayerOptions(
    this.tool, {
    this.size = 24.0,
    this.opacity = 0.6,
    this.onMessage,
  }) : super(rebuild: tool.changes);
}

class MeasureLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MeasureLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as MeasureLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, MeasureLayerOptions options, MapState map) {
    var origin = map.project(map.center);
    origin = origin.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    final measures = options.tool.target.toList()..add(map.center);

    return Stack(
      overflow: Overflow.clip,
      children: [
        _buildCross(origin),
        _buildTrack(context, size, options, map, measures),
        ...measures.take(measures.length - 1).map((point) => _buildPoint(context, options, map, point)),
        if (measures.isNotEmpty) _buildLabel(context, options, map, measures)
      ],
    );
  }

  Positioned _buildCross(CustomPoint<num> origin) {
    return Positioned(
      left: origin.x - 28,
      top: origin.y - 28,
      child: SizedBox(
        width: 56,
        height: 56,
        child: CustomPaint(
          painter: CrossPainter(),
        ),
      ),
    );
  }

  Widget _buildTrack(
    BuildContext context,
    Size size,
    MeasureLayerOptions options,
    MapState map,
    List<LatLng> points,
  ) {
    var offsets = points.map((point) {
      var pos = map.project(point);
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = Colors.lightBlue;

    return Opacity(
      opacity: options.opacity,
      child: CustomPaint(
        painter: LineStringPainter(
          offsets: offsets,
          color: color,
        ),
        size: size,
      ),
    );
  }

  Widget _buildPoint(
    BuildContext context,
    MeasureLayerOptions options,
    MapState map,
    LatLng point,
  ) {
    var size = options.size;
    var pos = map.project(point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      width: size,
      height: size,
      left: pos.x,
      top: pos.y,
      child: Opacity(
        opacity: options.opacity,
        child: CustomPaint(
          painter: PointPainter(
            size: size,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  _buildLabel(
    BuildContext context,
    MeasureLayerOptions options,
    MapState map,
    List<LatLng> points,
  ) {
    var pos = map.project(points.last);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var previous = points.first;
    final double distance = points.skip(1).fold(0, (value, point) {
      value += _distance(previous, point);
      previous = point;
      return value;
    });

    return Positioned(
      left: pos.x,
      top: pos.y + options.size,
      child: CustomPaint(
        painter: LabelPainter(
          "${formatDistance(distance)}",
          top: options.size / 2 + 4,
        ),
      ),
    );
  }

  _distance(LatLng previous, LatLng point) {
    return ProjMath.eucledianDistance(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
  }
}
