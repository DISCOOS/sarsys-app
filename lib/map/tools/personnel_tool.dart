import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class PersonnelTool extends MapTool with MapSelectable<Personnel> {
  final User user;
  final TrackingBloc bloc;
  final bool includeRetired;
  final MapController controller;
  final ActionCallback onMessage;

  final bool Function() _active;

  @override
  bool active() => _active();

  PersonnelTool(
    this.bloc, {
    @required this.user,
    @required this.controller,
    @required bool Function() active,
    this.onMessage,
    this.includeRetired = false,
    // Added debugging information, see https://github.com/DISCOOS/sarsys-app/issues/16
  })  : assert(user != null, "User must be authenicated"),
        _active = active;

  @override
  Iterable<Personnel> get targets => bloc.personnel
      .asTrackingIds(
        exclude: includeRetired ? [] : [TrackingStatus.Closed],
      )
      .values;

  @override
  void doProcessTap(BuildContext context, List<Personnel> personnel) {
    _show(context, personnel);
  }

  @override
  LatLng toPoint(Personnel personnel) {
    return toLatLng(bloc.tracking[personnel.tracking.uuid].point);
  }

  void _show(BuildContext context, List<Personnel> personnel) {
    if (personnel.length == 1) {
      _showInfo(context, personnel.first);
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
            child: SelectorPanel<Personnel>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg personnel",
              items: personnel,
              onSelected: _showInfo,
              itemBuilder: (BuildContext context, Personnel personnel) => Text("${personnel.name}"),
            ),
          );
        },
      );
    }
  }

  void _showInfo(BuildContext context, Personnel personnel) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final tracking = bloc.tracking[personnel.tracking.uuid];
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: PersonnelWidget(
              personnel: personnel,
              tracking: tracking,
              devices: bloc.devices(personnel.tracking.uuid),
              onMessage: onMessage,
              withActions: user.isCommander == true,
              organization: FleetMapService().fetchOrganization(Defaults.orgId),
              onDelete: () => Navigator.pop(context),
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
