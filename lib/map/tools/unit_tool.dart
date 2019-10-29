import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:SarSys/widgets/unit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class UnitTool extends MapTool with MapSelectable<Unit> {
  final User user;
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  final bool includeRetired;

  final bool Function() _active;

  @override
  bool active() => _active();

  UnitTool(
    this.bloc, {
    @required this.user,
    @required bool Function() active,
    this.onMessage,
    this.includeRetired = false,
  }) : _active = active;

  @override
  Iterable<Unit> get targets => bloc.units.asTrackingIds(exclude: includeRetired ? [] : [TrackingStatus.Closed]).values;

  @override
  void doProcessTap(BuildContext context, List<Unit> units) {
    _show(context, units);
  }

  @override
  LatLng toPoint(Unit unit) {
    return toLatLng(bloc.tracking[unit.tracking].point);
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

  void _showInfo(BuildContext context, Unit unit) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final tracking = bloc.tracking[unit.tracking];
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(550.0, MediaQuery.of(context).size.height - 96),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: UnitInfoPanel(
                unit: unit,
                tracking: tracking,
                devices: tracking.devices.map((id) => bloc.deviceBloc.devices[id]).where((unit) => unit != null),
                onMessage: onMessage,
                withActions: user?.isCommander == true,
                onComplete: (_) => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
