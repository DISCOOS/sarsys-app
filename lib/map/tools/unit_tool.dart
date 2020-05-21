import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/selector_widget.dart';
import 'package:SarSys/widgets/unit_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class UnitTool extends MapTool with MapSelectable<Unit> {
  final User user;
  final TrackingBloc bloc;
  final bool includeRetired;
  final MapController controller;
  final ActionCallback onMessage;

  final bool Function() _active;

  @override
  bool active() => _active();

  UnitTool(
    this.bloc, {
    @required this.user,
    @required this.controller,
    @required bool Function() active,
    this.onMessage,
    this.includeRetired = false,
  }) : _active = active;

  @override
  Iterable<Unit> get targets => bloc.units
      .where(
        exclude: includeRetired ? [] : [TrackingStatus.closed],
      )
      .trackables;

  @override
  void doProcessTap(BuildContext context, List<Unit> units) {
    _show(context, units);
  }

  @override
  LatLng toPoint(Unit unit) {
    return toLatLng(bloc.trackings[unit.tracking.uuid]?.position?.geometry);
  }

  void _show(BuildContext context, List<Unit> units) {
    if (units.length == 1) {
      _showInfo(context, units.first);
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
            child: SelectorWidget<Unit>(
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
        final tracking = bloc.trackings[unit.tracking.uuid];
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: UnitWidget(
              unit: unit,
              tracking: tracking,
              devices: bloc.devices(unit.tracking.uuid),
              onMessage: onMessage,
              withActions: user?.isCommander == true,
              onComplete: (_) => Navigator.pop(context),
              onGoto: (point) => _goto(context, point),
            ),
          ),
        );
      },
    );
  }

  void _goto(BuildContext context, Point point) {
    controller.move(toLatLng(point), controller.zoom);
    Navigator.pop(context);
  }
}
