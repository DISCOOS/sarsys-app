import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class PersonnelTool extends MapTool with MapSelectable<Personnel> {
  final User user;
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  final bool includeRetired;

  final bool Function() _active;

  @override
  bool active() => _active();

  PersonnelTool(
    this.bloc, {
    @required this.user,
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
    return toLatLng(bloc.tracking[personnel.tracking].point);
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
        final tracking = bloc.tracking[personnel.tracking];
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(550.0, MediaQuery.of(context).size.height - 96),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: PersonnelInfoPanel(
                personnel: personnel,
                tracking: tracking,
                devices:
                    tracking.devices.map((id) => bloc.deviceBloc.devices[id]).where((personnel) => personnel != null),
                onMessage: onMessage,
                withActions: user.isCommander == true,
                organization: AssetsService().fetchOrganization(Defaults.organization),
                onDelete: () => Navigator.pop(context),
                onComplete: (_) => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
