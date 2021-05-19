import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/core/presentation/widgets/list_selector_widget.dart';

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
  Iterable<Device> get targets => bloc.deviceBloc.values;

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
            child: ListSelectorWidget<Device>(
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
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: StreamBuilder<Device>(
              initialData: device,
              stream: context.bloc<DeviceBloc>().onChanged(device),
              builder: (context, snapshot) {
                if (snapshot.data is Device) {
                  device = snapshot.data;
                }
                final unit = bloc.units.find(device);
                final personnel = bloc.personnels.find(device);
                final tracking = _ensureTracking(unit, personnel);
                return DeviceWidget(
                  withMap: false,
                  unit: unit,
                  device: device,
                  tracking: tracking,
                  personnel: personnel,
                  onMessage: onMessage,
                  onGoto: (point) => _goto(context, point),
                  onCompleted: (_) => Navigator.pop(context),
                  withActions: bloc.operationBloc.isAuthorizedAs(UserRole.commander),
                );
              },
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
