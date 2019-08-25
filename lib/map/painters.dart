import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PointPainter extends CustomPainter {
  final double size;
  final Color color;
  final double opacity;

  const PointPainter({
    this.size,
    this.color,
    this.opacity = 0.6,
  });

  @override
  void paint(Canvas canvas, _) {
    final paint = Paint()..color = Colors.white;
    final radius = size / 2.0;
    final offset = size / 2.0;
    final center = Offset(offset, offset - 1);
    canvas.drawCircle(center, radius, paint);

    var path = Path();
    path.addOval(Rect.fromCircle(center: center.translate(0, 0), radius: radius + 1));
    canvas.drawShadow(path, Colors.black45, 2, true);

    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, paint);
    canvas.drawCircle(center, 1, paint..color = Colors.black);
  }

  @override
  bool shouldRepaint(PointPainter oldPainter) {
    return oldPainter.size != size || oldPainter.opacity != opacity;
  }
}

class LabelPainter extends CustomPainter {
  final String label;

  const LabelPainter(this.label);

  @override
  void paint(Canvas canvas, _) {
    final paint = Paint()..color = Colors.white;

    var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 12.0, textAlign: TextAlign.left))
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText(label);
    var p = builder.build()..layout(ui.ParagraphConstraints(width: 120));
    var height = p.height;
    var width = p.maxIntrinsicWidth;
    var rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 22),
        width: width + 4,
        height: height + 4,
      ),
      Radius.circular(4),
    );
    var path = Path()..addRRect(rect);
    canvas.drawShadow(path, Colors.black45, 2, true);
    canvas.drawRRect(rect, paint);
    canvas.drawParagraph(p, Offset(-width / 2, height + 1));
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
  final double borderStrokeWidth;
  final bool isFilled;

  LineStringPainter(
    this.offsets,
    this.color,
    this.borderColor,
    this.borderStrokeWidth,
    this.isFilled,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = Paint()
      ..strokeWidth = borderStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..color = color;

    var path = Path();
    path.addPolygon(offsets, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineStringPainter other) => false;
}

class CrossPainter extends CustomPainter {
  Paint _paint;
  final _gap = 15.0;
  final _length = 40.0;

  CrossPainter({color: Colors.red}) {
    _paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    canvas.drawCircle(center, 2.0, _paint);
    canvas.drawLine(center.translate(-_gap, 0), center.translate(-_length, 0), _paint);
    canvas.drawLine(center.translate(_gap, 0), center.translate(_length, 0), _paint);
    canvas.drawLine(center.translate(0, _gap), center.translate(0, _length), _paint);
    canvas.drawLine(center.translate(0, -_gap), center.translate(0, -_length), _paint);
  }

  @override
  bool shouldRepaint(CrossPainter oldDelegate) {
    return false;
  }
}
