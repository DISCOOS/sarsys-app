import 'dart:math';
import 'dart:ui' as ui;
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class ScalebarOption extends LayerOptions {
  static const SCALES = const [
    25000000.0,
    15000000.0,
    8000000.0,
    4000000.0,
    2000000.0,
    1000000.0,
    500000.0,
    250000.0,
    100000.0,
    50000.0,
    25000.0,
    15000.0,
    8000.0,
    4000.0,
    2000.0,
    1000.0,
    500.0,
    250.0,
    100.0,
    50.0,
    25.0,
    10.0,
    5.0
  ];

  TextStyle textStyle;
  Color lineColor;
  double lineWidth;
  List<double> scales;
  final EdgeInsets padding;
  Alignment alignment;

  ScalebarOption(
      {this.textStyle,
      this.lineColor = Colors.white,
      this.lineWidth = 2,
      this.padding,
      this.alignment = Alignment.bottomLeft,
      this.scales = SCALES});
}

class ScaleBar implements MapPlugin {
  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    if (options is ScalebarOption) {
      return IgnorePointer(
          child: StreamBuilder<void>(
              stream: stream,
              builder: (context, snapshot) {
                var zoom = map.zoom;
                var distance = toDistance(options.scales, zoom);
                var center = map.center;
                var start = map.project(center);
                var targetPoint = _calculateEndingGlobalCoordinates(center, 90, distance);
                var end = map.project(targetPoint);
                var displayDistance =
                    distance > 999 ? '${(distance / 1000).toStringAsFixed(0)} km' : '${distance.toStringAsFixed(0)} m';
                double width = (end.x - start.x);

                return Align(
                  alignment: options.alignment,
                  child: SizedBox(
                    height: 48,
                    child: CustomPaint(
                      painter: ScalePainter(
                        width,
                        displayDistance,
                        lineColor: options.lineColor,
                        lineWidth: options.lineWidth,
                        padding: options.padding,
                        textStyle: options.textStyle,
                      ),
                    ),
                  ),
                );
              }));
    }
    throw Exception('Unknown options type for ScaleLayerPlugin: $options');
  }

  static double toDistance(List<double> scales, double zoom) => scales[max(0, min(21, zoom.round() + 1))].toDouble();

  @override
  bool supportsLayer(LayerOptions options) {
    return options is ScalebarOption;
  }
}

class ScalePainter extends CustomPainter {
  ScalePainter(this.width, this.text, {this.padding, this.textStyle, this.lineWidth, this.lineColor});
  final double width;
  final EdgeInsets padding;
  final String text;
  TextStyle textStyle;
  double lineWidth;
  Color lineColor;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeCap = StrokeCap.square
      ..strokeWidth = lineWidth;

    var sizeForStartEnd = 4;
    var paddingLeft = padding == null ? 0.0 : padding.left + sizeForStartEnd / 2;
    var paddingTop = padding == null ? 0.0 : padding.top;

    var textSpan = TextSpan(style: textStyle, text: text);
    var textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(width / 2 - textPainter.width / 2 + paddingLeft, paddingTop));
    paddingTop += textPainter.height;
    var p1 = Offset(paddingLeft, sizeForStartEnd + paddingTop);
    var p2 = Offset(paddingLeft + width, sizeForStartEnd + paddingTop);
    // draw start line
    canvas.drawLine(Offset(paddingLeft, paddingTop), Offset(paddingLeft, sizeForStartEnd + paddingTop), paint);
    // draw end line
    canvas.drawLine(
        Offset(width + paddingLeft, paddingTop), Offset(width + paddingLeft, sizeForStartEnd + paddingTop), paint);
    // draw bottom line
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

LatLng _calculateEndingGlobalCoordinates(LatLng start, double startBearing, double distance) {
  ProjCoordinate ending = ProjMath.calculateEndingGlobalCoordinates(
    start.latitude,
    start.longitude,
    startBearing,
    distance,
  );
  return LatLng(ending.y, ending.x);
}
