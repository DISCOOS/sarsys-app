import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/core/utils/ui.dart';
import 'package:timer_builder/timer_builder.dart';

class CoordinateWidget extends StatelessWidget {
  const CoordinateWidget({
    Key key,
    this.timestamp,
    this.point,
    this.onGoto,
    this.accuracy,
    this.onMessage,
    this.onComplete,
    this.isDense = true,
    this.withIcons = true,
    this.withNavigation = true,
  }) : super(key: key);

  final Point point;
  final bool isDense;
  final bool withIcons;
  final double accuracy;
  final DateTime timestamp;
  final bool withNavigation;
  final VoidCallback onComplete;
  final MessageCallback onMessage;
  final ValueChanged<Point> onGoto;

  @override
  Widget build(BuildContext context) {
    final hasAccuracy = accuracy != null;
    final hasTimestamp = timestamp != null;
    final hasAction = withNavigation && point != null;
    return hasAction || hasTimestamp || hasAccuracy
        ? Row(
            mainAxisSize: isDense ? MainAxisSize.min : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: hasAction && hasAccuracy ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _buildCoordinates(context),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Padding(
                  padding: EdgeInsets.only(top: !hasAction ? (isDense ? 8.0 : 14.0) : 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasAccuracy) _buildAccuracy(context),
                          if (hasAccuracy) SizedBox(height: 26),
                          if (hasTimestamp) _buildTimestamp(context),
                        ],
                      ),
                      if (hasAccuracy) SizedBox(height: isDense ? 8.0 : 16.0),
                      if (hasAction) _buildNavigateAction(context),
                    ],
                  ),
                ),
              )
            ],
          )
        : _buildCoordinates(context);
  }

  Widget _buildAccuracy(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('FEIL', style: Theme.of(context).textTheme.caption),
        Text.rich(
          TextSpan(text: '±${accuracy.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodyText2, children: [
            TextSpan(text: ' m', style: Theme.of(context).textTheme.caption),
          ]),
        ),
      ],
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('ALDER', style: Theme.of(context).textTheme.caption),
        TimerBuilder.periodic(
          const Duration(seconds: 1),
          builder: (context) => Text.rich(
            TextSpan(text: '${formatSince(timestamp)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigateAction(BuildContext context) {
    return GestureDetector(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.navigation,
            color: Colors.black45,
          ),
          Text("Naviger", style: Theme.of(context).textTheme.caption),
        ],
      ),
      onTap: point != null
          ? () {
              navigateToLatLng(context, toLatLng(point));
              _onComplete();
            }
          : null,
    );
  }

  Column _buildCoordinates(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        buildCopyableLocation(
          context,
          label: "UTM",
          icon: withIcons ? Icons.my_location : null,
          formatter: (point) => toUTM(point, prefix: "", empty: "Ingen"),
        ),
        buildCopyableLocation(
          context,
          label: "Desimalgrader (DD)",
          icon: withIcons ? Icons.my_location : null,
          formatter: (point) => toDD(point, prefix: "", empty: "Ingen"),
        ),
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
        isDense: isDense,
        onMessage: onMessage,
        onComplete: _onComplete,
        value: formatter(point),
        onTap: () => _onGoto(point),
        icon: icon == null ? null : Icon(icon),
      );

  void _onComplete() {
    if (onComplete != null) onComplete();
  }

  void _onGoto(Point point) {
    if (onGoto != null && point != null) onGoto(point);
  }
}
