import 'package:flutter/material.dart';

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
