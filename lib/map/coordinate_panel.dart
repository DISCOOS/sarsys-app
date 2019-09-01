import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';

class CoordinatePanel extends StatelessWidget {
  final Point point;
  const CoordinatePanel({
    Key key,
    @required this.point,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(16.0),
      height: 80.0,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (point != null) Text(toUTM(point), textAlign: TextAlign.start),
          if (point != null) Text(toDD(point), textAlign: TextAlign.start),
        ],
      ),
    );
  }
}
