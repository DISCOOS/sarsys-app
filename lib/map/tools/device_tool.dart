import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/device_info_panel.dart';
import 'package:SarSys/widgets/selector_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

class DeviceTool extends MapTool with MapSelectable<Device> {
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  final bool Function() _active;

  @override
  bool active() => _active();

  DeviceTool(
    this.bloc, {
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

  void _showInfo(BuildContext context, Device device) {
    final unit = bloc.getUnitsByDeviceId()[device.id];
    final tracking = bloc.tracking[unit?.tracking];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(494.0, MediaQuery.of(context).size.height - 96),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: DeviceInfoPanel(
                unit: unit,
                device: device,
                tracking: tracking,
                onMessage: onMessage,
                organization: AssetsService().fetchOrganization(Defaults.orgId),
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
