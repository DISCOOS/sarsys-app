import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/poi_info_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class PositionTool extends MapTool {
  final MessageCallback onMessage;
  final VoidCallback onHide;
  final ValueChanged<LatLng> onShow;
  final ValueChanged<String> onCopy;

  @override
  bool active() => true;

  PositionTool({
    @required this.onShow,
    @required this.onHide,
    @required this.onCopy,
    @required this.onMessage,
  });

  @override
  bool onLongPress(BuildContext context, LatLng point, double tolerance, onMatch) {
    _show(context, point);
    return true;
  }

  void _show(BuildContext context, LatLng point) async {
    onShow(point);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: POIInfoPanel(
            poi: POI(
              name: "Posisjon",
              point: Point.now(point.latitude, point.longitude),
              type: POIType.Any,
            ),
            onMessage: onMessage,
            onCopy: onCopy,
            onCancel: () {
              onHide();
              Navigator.pop(context, false);
            },
            onComplete: () => Navigator.pop(context, true),
          ),
        );
      },
    );
    if (result != true) onHide();
  }
}
