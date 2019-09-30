import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:SarSys/widgets/unit_info_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class UnitTool extends MapTool with MapSelectable<Unit> {
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  final bool includeRetired;

  UnitTool(
    this.bloc, {
    bool active = false,
    this.onMessage,
    this.includeRetired = false,
  }) : super(active);

  @override
  Iterable<Unit> get targets => bloc.getTrackedUnits(exclude: includeRetired ? [] : [TrackingStatus.Closed]).values;

  @override
  void doProcessTap(BuildContext context, List<Unit> units) {
    _show(context, units);
  }

  @override
  LatLng toPoint(Unit unit) {
    return toLatLng(bloc.tracking[unit.tracking].location);
  }

  void _show(BuildContext context, List<Unit> units) {
    if (units.length == 1) {
      _showInfo(context, units.first);
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
            child: SelectorPanel<Unit>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg enhet",
              items: units,
              onSelected: _showInfo,
              itemBuilder: (BuildContext context, Unit unit) => Text("${unit.name}"),
            ),
          );
        },
      );
    }
  }

  void _showInfo(BuildContext context, Unit unit) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(432.0, MediaQuery.of(context).size.height - 96),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: UnitInfoPanel(
                unit: unit,
                bloc: bloc,
                onMessage: onMessage,
                onComplete: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
