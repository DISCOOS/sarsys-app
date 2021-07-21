// @dart=2.11

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PointPainter extends CustomPainter {
  final double size;
  final Color color;
  final double opacity;
  final double outer;
  final double centerSize;
  final Color centerColor;

  const PointPainter({
    this.size,
    this.color,
    this.outer,
    this.centerColor,
    this.centerSize = 2,
    this.opacity = 0.54,
  });

  @override
  void paint(Canvas canvas, _) {
    final offset = 0.0;
    final radius = size / 2.0;
    final paint = Paint()..color = Colors.white.withOpacity(opacity);
    final center = Offset(offset, offset);
    canvas.drawCircle(center, radius, paint);

    paint.color = color.withOpacity(opacity);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, paint);
    if (outer != null) {
      canvas.drawCircle(center, outer - 2, paint);
    }
    canvas.drawCircle(center, centerSize, paint..color = centerColor ?? Colors.black);
  }

  @override
  bool shouldRepaint(PointPainter oldPainter) {
    return oldPainter.size != size || oldPainter.opacity != opacity;
  }
}

class LabelPainter extends CustomPainter {
  final String label;
  final double top;
  final double width;
  final double padding;
  final double opacity;
  final double fontSize;

  const LabelPainter(
    this.label, {
    this.top = 0,
    this.width = 200,
    this.padding = 4,
    this.opacity = 0.4,
    this.fontSize = 12.0,
  });

  @override
  void paint(Canvas canvas, _) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);

    var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize, textAlign: TextAlign.left))
      ..pushStyle(ui.TextStyle(color: Colors.black, height: 1.0))
      ..addText(label);
    var p = builder.build()..layout(ui.ParagraphConstraints(width: this.width));
    var height = p.height;
    var width = p.maxIntrinsicWidth;
    var rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, top),
        width: width + padding,
        height: height + padding,
      ),
      Radius.circular(4),
    );
    var path = Path()..addRRect(rect);
    canvas.drawShadow(path, Colors.black45, 2, true);
    canvas.drawRRect(rect, paint);
    canvas.drawParagraph(p, Offset(-width / 2, (top - height / 2)));
  }

  @override
  bool shouldRepaint(LabelPainter oldPainter) {
    return true;
  }
}

class LineStringPainter extends CustomPainter {
  final List<Offset> offsets;

  final Color color;
  final Color borderColor;
  final double opacity;
  final double borderStrokeWidth;
  final bool isFilled;

  LineStringPainter({
    this.offsets,
    this.color,
    this.borderColor,
    this.opacity = 0.6,
    this.borderStrokeWidth = 4.0,
    this.isFilled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.length < 2) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = Paint()
      ..strokeWidth = borderStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..color = color.withOpacity(opacity);

    var path = Path();
    path.addPolygon(offsets, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineStringPainter other) => false;
}

class CrossPainter extends CustomPainter {
  Paint _paint;
  final gap;
  final length;
  final opacity;

  CrossPainter({Color color: Colors.blue, this.gap: 12.0, this.length: 24.0, this.opacity = 0.6}) {
    _paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    canvas.drawCircle(center, 2.0, _paint);
    canvas.drawLine(center.translate(-gap, 0), center.translate(-length, 0), _paint);
    canvas.drawLine(center.translate(gap, 0), center.translate(length, 0), _paint);
    canvas.drawLine(center.translate(0, gap), center.translate(0, length), _paint);
    canvas.drawLine(center.translate(0, -gap), center.translate(0, -length), _paint);
  }

  @override
  bool shouldRepaint(CrossPainter oldDelegate) {
    return false;
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
