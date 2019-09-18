import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/poi_info_panel.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class POITool extends MapTool with MapSelectable<POI> {
  final IncidentBloc bloc;
  final MessageCallback onMessage;
  final bool includeRetired;

  POITool(
    this.bloc, {
    bool active = false,
    this.onMessage,
    this.includeRetired = false,
  }) : super(active);

  @override
  Iterable<POI> get targets => bloc.isUnset
      ? []
      : [
          POI(name: "IPP", point: bloc.current.ipp),
          POI(name: "Oppmøte", point: bloc.current.meetup),
        ];

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
      final style = Theme.of(context).textTheme.title;
      final size = MediaQuery.of(context).size;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.white,
            child: SelectorPanel<POI>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg enhet",
              items: items,
              onSelected: _showInfo,
              itemBuilder: (BuildContext context, POI poi) => Text("${poi.name}"),
            ),
          );
        },
      );
    }
  }

  void _showInfo(BuildContext context, POI poi) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: POIInfoPanel(
            poi: poi,
            onMessage: onMessage,
          ),
        );
      },
    );
  }
}