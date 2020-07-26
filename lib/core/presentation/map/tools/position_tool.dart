import 'package:SarSys/core/presentation/map/layers/poi_layer.dart';
import 'package:SarSys/core/presentation/map/tools/map_tools.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/operation/presentation/widgets/poi_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class PositionTool extends MapTool {
  final VoidCallback onHide;
  final MapController controller;
  final ActionCallback onMessage;
  final ValueChanged<LatLng> onShow;
  final ValueChanged<String> onCopy;

  @override
  bool active() => true;

  PositionTool({
    @required this.onShow,
    @required this.onHide,
    @required this.onCopy,
    @required this.onMessage,
    @required this.controller,
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
          child: POIWidget(
            poi: POI(
              name: "Posisjon",
              point: Point.fromCoords(
                lat: point.latitude,
                lon: point.longitude,
              ),
              type: POIType.Any,
            ),
            onMessage: onMessage,
            onCopy: onCopy,
            onCancel: () {
              onHide();
              Navigator.pop(context, false);
            },
            onComplete: () => Navigator.pop(context, true),
            onGoto: (point) => _goto(context, point),
          ),
        );
      },
    );
    if (result != true) onHide();
  }

  void _goto(BuildContext context, Point point) {
    controller.move(toLatLng(point), controller.zoom);
    Navigator.pop(context);
  }
}
