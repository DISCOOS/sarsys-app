import 'package:SarSys/map/cross_painter.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class CoordinateLayerOptions extends LayerOptions {
  Alignment align;

  CoordinateLayerOptions({
    this.align = Alignment.bottomLeft,
    Stream<void> rebuild,
  }) : super(rebuild: rebuild);
}

class CoordinateLayer extends MapPlugin {
  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    final Point center = toPoint(map.center);
    final params = options as CoordinateLayerOptions;
    var origin = map.project(map.center);
    origin = origin.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return StreamBuilder<Object>(
        stream: stream,
        builder: (context, snapshot) {
          return Stack(
            children: <Widget>[
              Positioned(
                  left: origin.x - 28,
                  top: origin.y - 28,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CustomPaint(
                      painter: CrossPainter(),
                    ),
                  )),
              Align(
                alignment: params.align,
                child: Container(
                  margin: EdgeInsets.all(16.0),
                  padding: EdgeInsets.all(16.0),
                  height: 72.0,
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(8.0)),
                  child: Column(
                    children: <Widget>[
                      if (center != null) Text(toUTM(center)),
                      if (center != null) Text(toDD(center)),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
  }

  @override
  bool supportsLayer(LayerOptions options) {
    return options is CoordinateLayerOptions;
  }
}