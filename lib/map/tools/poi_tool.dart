import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/usecase/poi.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/poi_widget.dart';
import 'package:SarSys/widgets/selector_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class POITool extends MapTool with MapSelectable<POI> {
  final IncidentBloc bloc;
  final bool includeRetired;
  final MapController controller;
  final ActionCallback onMessage;

  final bool Function() _active;

  @override
  bool active() => _active();

  POITool(
    this.bloc, {
    @required bool Function() active,
    @required this.controller,
    this.onMessage,
    this.includeRetired = false,
  }) : _active = active;

  @override
  Iterable<POI> get targets => bloc.isUnset ? [] : POILayer.toItems(bloc?.selected);

  @override
  void doProcessTap(BuildContext context, List<POI> items) {
    _show(context, items);
  }

  @override
  LatLng toPoint(POI poi) {
    return toLatLng(poi.point);
  }

  void _show(BuildContext context, List<POI> items) {
    if (items.length == 1) {
      _showInfo(context, items.first);
    } else {
      final style = Theme.of(context).textTheme.headline6;
      final size = MediaQuery.of(context).size;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.white,
            child: SelectorWidget<POI>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg punkt",
              items: items,
              onSelected: _showInfo,
              itemBuilder: (BuildContext context, POI poi) => Text("${poi.name}"),
            ),
          );
        },
      );
    }
  }

  void _showInfo(BuildContext context, POI poi) async {
    var actual = poi.point;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: StatefulBuilder(builder: (context, StateSetter setState) {
            actual ??= poi.point;
            return POIWidget(
              poi: POIType.IPP == poi.type
                  ? POI(
                      name: "IPP",
                      point: actual,
                      type: POIType.IPP,
                    )
                  : POI(
                      name: "Oppmøte",
                      point: actual,
                      type: POIType.Meetup,
                    ),
              onMessage: onMessage,
              onEdit: () async => (poi.type == POIType.IPP ? editIPP(bloc.selected) : editMeetup(bloc.selected)),
              onChanged: (changed) => setState(() => actual = changed),
              onComplete: () => Navigator.pop(context),
              onGoto: (point) => _goto(context, point),
            );
          }),
        );
      },
    );
  }

  void _goto(BuildContext context, Point point) {
    controller.move(toLatLng(point), controller.zoom);
    Navigator.pop(context);
  }
}
