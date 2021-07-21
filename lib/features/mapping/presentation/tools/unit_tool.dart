// @dart=2.11

import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/presentation/widgets/list_selector_widget.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';

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
            child: ListSelectorWidget<Unit>(
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
            child: StreamBuilder<Unit>(
              initialData: unit,
              stream: context.read<UnitBloc>().onChanged(unit.uuid),
              builder: (context, snapshot) {
                if (snapshot.data is Unit) {
                  unit = snapshot.data;
                }
                return UnitWidget(
                  unit: unit,
                  withMap: false,
                  tracking: tracking,
                  onMessage: onMessage,
                  withActions: bloc.operationBloc.isAuthorizedAs(UserRole.commander),
                  onGoto: (point) => _goto(context, point),
                  devices: bloc.devices(unit.tracking.uuid),
                  onCompleted: (_) => Navigator.pop(context),
                );
              },
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
