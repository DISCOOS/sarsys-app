import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/widgets/selector_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

class DeviceTool extends MapTool with MapSelectable<Device> {
  final User user;
  final TrackingBloc bloc;
  final bool Function() _active;
  final MapController controller;
  final ActionCallback onMessage;

  @override
  bool active() => _active();

  DeviceTool(
    this.bloc, {
    @required this.user,
    @required this.controller,
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
    return toLatLng(device?.position?.geometry);
  }

  void _show(BuildContext context, List<Device> devices) {
    if (devices.length == 1) {
      _showInfo(context, devices.first);
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
            child: SelectorWidget<Device>(
              size: size,
              style: style,
              icon: Icons.group,
              title: "Velg appparat",
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
    final personnel = bloc.personnels.find(device);
    final tracking = _ensureTracking(unit, personnel);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: DeviceWidget(
              unit: unit,
              personnel: personnel,
              device: device,
              tracking: tracking,
              onMessage: onMessage,
              withActions: user?.isCommander == true,
              organization: FleetMapService().fetchOrganization(Defaults.orgId),
              onCompleted: (_) => Navigator.pop(context),
              onGoto: (point) => _goto(context, point),
            ),
          ),
        );
      },
    );
  }

  Tracking _ensureTracking(Unit unit, Personnel personnel) =>
      bloc.trackings[unit?.tracking?.uuid] ?? bloc.trackings[personnel?.tracking?.uuid];

  void _goto(BuildContext context, Point point) {
    controller.move(toLatLng(point), controller.zoom);
    Navigator.pop(context);
  }
}
