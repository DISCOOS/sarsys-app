import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class IconLayerOptions extends LayerOptions {
  List<LatLng> points;
  double bearing;
  double opacity;
  Icon icon;
  Anchor anchor;

  IconLayerOptions(
    this.points,
    this.icon, {
    Stream<void> rebuild,
    this.bearing,
    this.opacity = 1.0,
  })  : this.anchor = Anchor.forPos(AnchorPos.align(AnchorAlign.center), icon.size, icon.size),
        super(rebuild: rebuild);
}

class IconLayer implements MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is IconLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    final params = options as IconLayerOptions;
    return StreamBuilder<void>(
      stream: stream, // a Stream<int> or null
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        List<Widget> icons = params.points
            .where((point) => map.bounds.contains(point))
            .map((point) => _buildIcon(map, params, point))
            .toList();
        return icons.isEmpty
            ? Container()
            : Stack(
                children: icons,
              );
      },
    );
  }

  Widget _buildIcon(MapState map, IconLayerOptions params, LatLng point) {
    var size = params.icon.size;
    var anchor = params.anchor;
    var pos = map.project(point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    var pixelPosX = (pos.x - (size - anchor.left)).toDouble();
    var pixelPosY = (pos.y - (size - anchor.top)).toDouble();

    return Positioned(
      width: size,
      height: size,
      left: pixelPosX,
      top: pixelPosY,
      child: Stack(
        children: [
          Container(
            child: Opacity(
              opacity: params.opacity,
              child: params.icon,
            ),
          ),
          if (params.bearing != null)
            Opacity(
              opacity: 0.54,
              child: CustomPaint(
                painter: BearingPainter(params.bearing),
                size: Size(size, size),
              ),
            ),
        ],
      ),
    );
  }
}

class BearingPainter extends CustomPainter {
  final Paint bearingPaint;
  final Paint bearingsPaint;

  double bearing;

  BearingPainter(this.bearing)
      : bearingPaint = Paint(),
        bearingsPaint = Paint() {
    bearingPaint.color = Colors.red;
    bearingPaint.style = PaintingStyle.stroke;
    bearingPaint.strokeWidth = 2.0;
    bearingsPaint.color = Colors.red;
    bearingsPaint.style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    canvas.save();

    canvas.translate(radius, radius);

    canvas.rotate(this.bearing * pi / 180);

    Path path = Path();
    path.moveTo(0.0, -radius);
    path.lineTo(0.0, radius / 4);

    canvas.drawPath(path, bearingPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(BearingPainter oldDelegate) {
    return this.bearing != oldDelegate.bearing;
  }
}
