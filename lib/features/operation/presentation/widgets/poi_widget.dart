import 'package:SarSys/core/presentation/map/layers/poi_layer.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class POIWidget extends StatelessWidget {
  final POI poi;
  final ActionCallback onMessage;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final ValueChanged<String> onCopy;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Point> onChanged;
  final AsyncValueGetter<Either<bool, Point>> onEdit;

  const POIWidget({
    Key key,
    @required this.poi,
    @required this.onMessage,
    this.onEdit,
    this.onCopy,
    this.onGoto,
    this.onCancel,
    this.onChanged,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 300.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }

  Padding _buildHeader(TextTheme theme, BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('${poi.name}', style: theme.headline6),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: onCancel ?? onComplete,
            )
          ],
        ),
      );

  Row _buildLocationInfo(BuildContext context, TextTheme theme) => Row(
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
                  onTap: () => _onGoto(),
                  onComplete: onComplete,
                ),
                buildCopyableText(
                  context: context,
                  label: "Desimalgrader (DD)",
                  value: toDD(poi.point, prefix: ""),
                  onCopy: onCopy,
                  onMessage: onMessage,
                  onTap: () => _onGoto(),
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

  _onGoto() {
    if (onGoto != null) onGoto(poi.point);
  }
}
