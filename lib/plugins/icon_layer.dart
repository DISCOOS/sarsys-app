import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class IconLayerOptions extends LayerOptions {
  LatLng point;
  double bearing;
  double opacity;
  Icon icon;
  final Anchor _anchor;

  IconLayerOptions(
    this.point,
    this.icon, {
    Stream<void> rebuild,
    this.bearing,
    this.opacity = 1.0,
  })  : this._anchor = Anchor(icon.size, icon.size),
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
        var widget;
        if (map.bounds.contains(params.point)) {
          var pos = map.project(params.point);
          pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

          var pixelPosX = (pos.x - (params.icon.size - params._anchor.left)).toDouble();
          var pixelPosY = (pos.y - (params.icon.size - params._anchor.top)).toDouble();

          widget = Positioned(
            width: params.icon.size,
            height: params.icon.size,
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
                      size: Size(params.icon.size, params.icon.size),
                    ),
                  ),
              ],
            ),
          );
        }

        return Container(
          child: widget,
        );
      },
    );
  }

  /*

   */
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
