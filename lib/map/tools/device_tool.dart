import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/device.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class DeviceTool extends MapTool with MapSelectable<Device> {
  final User user;
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  final bool Function() _active;

  @override
  bool active() => _active();

  DeviceTool(
    this.bloc, {
    @required this.user,
    @required bool Function() active,
    this.onMessage,
  }) : _active = active;

  @override
  Iterable<Device> get targets => bloc.deviceBloc.devices.values;

  @override
  void doProcessTap(BuildContext context, List<Device> units) {
    _show(context, units);
  }

  @override
  LatLng toPoint(Device device) {
    return toLatLng(device?.point);
  }

  void _show(BuildContext context, List<Device> devices) {
    if (devices.length == 1) {
      _showInfo(context, devices.first);
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
            child: SelectorPanel<Device>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg enhet",
              items: devices,
              onSelected: _showInfo,
              itemBuilder: (BuildContext context, Device unit) => Text("${unit.name}"),
            ),
          );
        },
      );
    }
  }

  void _showInfo(BuildContext context, Device device) async {
    final unit = bloc.units.find(device);
    final personnel = bloc.personnel.find(device);
    final tracking = bloc.tracking[unit?.tracking];
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(tracking == null ? 496 : 680.0, MediaQuery.of(context).size.height),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: DeviceInfoPanel(
                unit: unit,
                personnel: personnel,
                device: device,
                tracking: tracking,
                onMessage: onMessage,
                withActions: user?.isCommander == true,
                organization: AssetsService().fetchOrganization(Defaults.organization),
                onChanged: (_) => Navigator.pop(context),
                onComplete: (_) => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
