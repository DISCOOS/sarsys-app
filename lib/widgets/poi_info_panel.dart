import 'dart:math' as math;
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class POIInfoPanel extends StatelessWidget {
  final POI poi;
  final MessageCallback onMessage;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final ValueChanged<String> onCopy;
  final ValueChanged<Point> onChanged;
  final AsyncValueGetter<Either<bool, Point>> onEdit;

  const POIInfoPanel({
    Key key,
    @required this.poi,
    @required this.onMessage,
    this.onEdit,
    this.onCopy,
    this.onCancel,
    this.onChanged,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      height: math.min(260.0, MediaQuery.of(context).size.height - 96),
      width: MediaQuery.of(context).size.width - 96,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(theme, context),
            Divider(),
            _buildLocationInfo(context, theme),
            if (onEdit != null) ...[
              Divider(),
              _buildActions(context),
            ]
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
            onPressed: onCancel ?? onComplete,
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
                onCopy: onCopy,
                onMessage: onMessage,
                onComplete: onComplete,
              ),
              buildCopyableText(
                context: context,
                label: "Desimalgrader (DD)",
                value: toDD(poi.point, prefix: ""),
                onCopy: onCopy,
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

  Widget _buildActions(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ButtonBarTheme(
          // make buttons use the appropriate styles for cards
          child: ButtonBar(
            alignment: MainAxisAlignment.start,
            children: <Widget>[
              _buildEditAction(context),
            ],
          ),
          data: ButtonBarThemeData(
            layoutBehavior: ButtonBarLayoutBehavior.constrained,
            buttonPadding: EdgeInsets.all(0.0),
          ),
        ),
      );

  Widget _buildEditAction(BuildContext context) {
    return Tooltip(
      message: "Endre posisjon",
      child: FlatButton(
        child: Text(
          "ENDRE",
          textAlign: TextAlign.center,
        ),
        onPressed: () async {
          final result = await onEdit();
          if (result.isRight()) {
            if (onChanged != null) onChanged(result.toIterable().first);
            if (onComplete != null) onComplete();
          }
        },
      ),
    );
  }
}
