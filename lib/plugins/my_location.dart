import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class MyLocationOptions extends LayerOptions {
  Color color;
  LatLng point;
  double bearing;
  double opacity;
  final double width;
  final double height;
  final Anchor _anchor;

  MyLocationOptions(
    this.point, {
    Stream<void> rebuild,
    this.bearing = 0.0,
    this.width = 30.0,
    this.height = 30.0,
    this.opacity = 1.00,
    this.color = Colors.green,
  })  : this._anchor = new Anchor(width, height),
        super(rebuild: rebuild);
}

class MyLocation implements MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MyLocationOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    if (options is MyLocationOptions) {
      return new StreamBuilder<void>(
        stream: stream, // a Stream<int> or null
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          var widget;
          if (map.bounds.contains(options.point)) {
            var pos = map.project(options.point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

            var pixelPosX = (pos.x - (options.width - options._anchor.left)).toDouble();
            var pixelPosY = (pos.y - (options.height - options._anchor.top)).toDouble();

            widget = new Positioned(
                width: options.width,
                height: options.height,
                left: pixelPosX,
                top: pixelPosY,
                child: new Stack(children: [
                  new Container(
                    child: Opacity(
                      opacity: options.opacity,
                      child: Icon(
                        Icons.my_location,
                        color: options.color,
                        size: 30.0,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 0.54,
                    child: new CustomPaint(
                      painter: new BearingPainter(options.bearing),
                      size: new Size(options.height, options.height),
                    ),
                  ),
                ]));
          }

          return new Container(
            child: widget,
          );
        },
      );
    }
    throw ("Unknown options type for MyLocation plugin: $options");
  }

  /*

   */
}

class BearingPainter extends CustomPainter {
  final Paint bearingPaint;
  final Paint bearingsPaint;

  double bearing;

  BearingPainter(this.bearing)
      : bearingPaint = new Paint(),
        bearingsPaint = new Paint() {
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

    Path path = new Path();
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
