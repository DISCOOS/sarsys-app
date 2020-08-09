import 'package:SarSys/features/mapping/presentation/widgets/coordinate_panel.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class CoordinateLayerOptions extends LayerOptions {
  Alignment align;

  CoordinateLayerOptions({
    this.align = Alignment.bottomLeft,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild);
}

class CoordinateLayer extends MapPlugin {
  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
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
                      painter: CrossPainter(color: Colors.black45),
                    ),
                  )),
              Align(
                alignment: params.align,
                child: CoordinatePanel(point: center),
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
