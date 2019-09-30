import 'dart:math';

import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';

class POIInfoPanel extends StatelessWidget {
  final POI poi;
  final MessageCallback onMessage;
  final VoidCallback onComplete;

  const POIInfoPanel({
    Key key,
    @required this.poi,
    @required this.onMessage,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      height: min(200.0, MediaQuery.of(context).size.height - 96),
      width: MediaQuery.of(context).size.width - 96,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(theme, context),
            Divider(),
            _buildLocationInfo(context, theme),
          ],
        ),
      ),
    );
  }

  Padding _buildHeader(TextTheme theme, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${poi.name}', style: theme.title),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: onComplete,
          )
        ],
      ),
    );
  }

  Row _buildLocationInfo(BuildContext context, TextTheme theme) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Column(
            children: <Widget>[
              buildCopyableText(
                context: context,
                label: "UTM",
                icon: Icon(Icons.my_location),
                value: toUTM(poi.point, prefix: ""),
                onTap: () => jumpToPoint(
                  context,
                  center: poi.point,
                ),
                onMessage: onMessage,
                onComplete: onComplete,
              ),
              buildCopyableText(
                context: context,
                label: "Desimalgrader (DD)",
                value: toDD(poi.point, prefix: ""),
                onTap: () => jumpToPoint(
                  context,
                  center: poi.point,
                ),
                onMessage: onMessage,
                onComplete: onComplete,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.navigation, color: Colors.black45),
                onPressed: () {
                  if (onComplete != null) onComplete();
                  navigateToLatLng(context, toLatLng(poi.point));
                },
              ),
              Text("Naviger", style: theme.caption),
            ],
          ),
        ),
      ],
    );
  }
}
