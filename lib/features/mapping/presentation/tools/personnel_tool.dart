import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/presentation/widgets/list_selector_widget.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';

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
  Iterable<Personnel> get targets => bloc.personnels
      .where(
        exclude: includeRetired ? [] : [TrackingStatus.closed],
      )
      .trackables;

  @override
  void doProcessTap(BuildContext context, List<Personnel> personnel) {
    _show(context, personnel);
  }

  @override
  LatLng toPoint(Personnel personnel) {
    return toLatLng(bloc.trackings[personnel.tracking.uuid]?.position?.geometry);
  }

  void _show(BuildContext context, List<Personnel> personnel) {
    if (personnel.length == 1) {
      _showInfo(context, personnel.first);
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
            child: ListSelectorWidget<Personnel>(
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
      builder: (BuildContext context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: StreamBuilder<Personnel>(
              initialData: personnel,
              stream: context.read<PersonnelBloc>().onChanged(personnel),
              builder: (context, snapshot) {
                if (snapshot.data is Personnel) {
                  personnel = snapshot.data;
                }
                final tracking = bloc.trackings[personnel.tracking.uuid];
                return PersonnelWidget(
                  withMap: false,
                  tracking: tracking,
                  personnel: personnel,
                  onMessage: onMessage,
                  onDeleted: () => Navigator.pop(context),
                  onCompleted: (_) => Navigator.pop(context),
                  onGoto: (point) => _goto(context, point),
                  devices: bloc.devices(personnel.tracking.uuid),
                  unit: context.read<UnitBloc>().repo.findPersonnel(personnel.uuid).firstOrNull,
                  withActions: context.read<OperationBloc>().isAuthorizedAs(UserRole.commander),
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
