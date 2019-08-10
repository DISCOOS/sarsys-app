import 'dart:ui';
import 'dart:math';

import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

typedef IconBuilder = Icon Function(BuildContext context, int index);

class IconLayerOptions extends LayerOptions {
  Iterable<LatLng> points;
  double bearing;
  double opacity;
  Icon icon;
  Text text;
  bool showBadge;
  AnchorAlign align;
  IconBuilder builder;

  IconLayerOptions(
    this.points, {
    this.icon,
    this.builder,
    this.bearing,
    this.showBadge = false,
    this.opacity = 1.0,
    this.align = AnchorAlign.center,
    Stream<void> rebuild,
  }) : super(rebuild: rebuild);
}

class IconLayer implements MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is IconLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    return IgnorePointer(
        child: stream == null
            ? Builder(
                builder: (context) => _buildLayer(context, options, map),
              )
            : StreamBuilder<void>(
                stream: stream, // a Stream<int> or null
                builder: (context, snapshot) => _buildLayer(context, options, map),
              ));
  }

  Widget _buildLayer(BuildContext context, IconLayerOptions params, MapState map) {
    int index = 0;
    List<Widget> icons = params.points
        .where((point) => map.bounds.contains(point))
        .map((point) => _buildIcon(context, map, params, point, index++))
        .toList();
    return icons.isEmpty
        ? Container()
        : Stack(
            children: icons,
          );
  }

  Widget _buildIcon(BuildContext context, MapState map, IconLayerOptions params, LatLng point, int index) {
    var icon = params.icon ?? params.builder(context, index);
    var size = icon.size;
    var anchor = Anchor.forPos(AnchorPos.align(params.align), icon.size, icon.size);
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
              child: Badge(
                child: icon,
                badgeColor: Colors.white70,
                toAnimate: false,
                showBadge: params.showBadge,
                position: BadgePosition.bottomRight(),
                badgeContent: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 10),
                ),
              ),
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
