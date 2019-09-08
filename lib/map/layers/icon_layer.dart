import 'dart:ui';

import 'package:SarSys/map/painters.dart';
import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

typedef IconBuilder = Icon Function(BuildContext context, int index);

class IconLayerOptions extends LayerOptions {
  Map<LatLng, String> points;
  double bearing;
  double opacity;
  Icon icon;
  Text text;
  bool showBadge;
  bool showLabels;
  AnchorAlign align;
  IconBuilder builder;

  IconLayerOptions(
    this.points, {
    this.icon,
    this.builder,
    this.bearing,
    this.showBadge = false,
    this.showLabels = true,
    this.opacity = 0.6,
    this.align = AnchorAlign.center,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild);
}

class IconLayer implements MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is IconLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return IgnorePointer(
      child: stream == null
          ? Builder(
              builder: (context) => _buildLayer(context, options, map),
            )
          : StreamBuilder<void>(
              stream: stream, // a Stream<int> or null
              builder: (context, snapshot) => _buildLayer(context, options, map),
            ),
    );
  }

  Widget _buildLayer(BuildContext context, IconLayerOptions params, MapState map) {
    int index = 0;
    List<Widget> icons = params.points.entries
        .where((entry) => map.bounds.contains(entry.key))
        .map((entry) => _buildIcon(context, map, params, entry.key, entry.value, index++))
        .toList();
    return icons.isEmpty
        ? Container()
        : Stack(
            children: icons,
          );
  }

  Widget _buildIcon(
    BuildContext context,
    MapState map,
    IconLayerOptions params,
    LatLng point,
    String label,
    int index,
  ) {
    var icon = params.icon ?? params.builder(context, index);
    var size = icon.size;
    var anchor = Anchor.forPos(AnchorPos.align(params.align), icon.size, icon.size);
    var pos = map.project(point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    var pixelPosX = (pos.x - (size - anchor.left)).toDouble();
    var pixelPosY = (pos.y - (size - anchor.top)).toDouble();

    return Positioned(
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
                position: BadgePosition.topRight(),
                badgeContent: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          if (params.showLabels && label != null)
            Positioned(
              left: size / 2,
              top: size,
              child: CustomPaint(
                painter: LabelPainter(label, top: size / 2),
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
