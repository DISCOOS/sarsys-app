import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/utils/ui_utils.dart';

class CoordinateView extends StatelessWidget {
  const CoordinateView({
    Key key,
    this.point,
    this.onGoto,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final Point point;
  final VoidCallback onComplete;
  final MessageCallback onMessage;
  final ValueChanged<Point> onGoto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Column(
            children: <Widget>[
              buildCopyableLocation(
                context,
                label: "UTM",
                icon: Icons.my_location,
                formatter: (point) => toUTM(point, prefix: "", empty: "Ingen"),
              ),
              buildCopyableLocation(
                context,
                label: "Desimalgrader (DD)",
                icon: Icons.my_location,
                formatter: (point) => toDD(point, prefix: "", empty: "Ingen"),
              ),
            ],
          ),
        ),
        if (point != null)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.navigation, color: Colors.black45),
                  onPressed: point != null
                      ? () {
                          navigateToLatLng(context, toLatLng(point));
                          _onComplete();
                        }
                      : null,
                ),
                Text("Naviger", style: Theme.of(context).textTheme.caption),
              ],
            ),
          )
      ],
    );
  }

  Widget buildCopyableLocation(
    BuildContext context, {
    String label,
    IconData icon,
    String formatter(Point point),
  }) =>
      buildCopyableText(
        context: context,
        label: label,
        icon: Icon(icon),
        onMessage: onMessage,
        onComplete: _onComplete,
        value: formatter(point),
        onTap: () => _onGoto(point),
      );

  void _onComplete() {
    if (onComplete != null) onComplete();
  }

  void _onGoto(Point point) {
    if (onGoto != null && point != null) onGoto(point);
  }
}
