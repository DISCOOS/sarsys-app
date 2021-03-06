import 'dart:async';

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:async/async.dart';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

class DeviceScreen extends Screen<_DeviceScreenState> {
  static const ROUTE = 'device';

  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Device device;

  const DeviceScreen({Key key, @required this.device}) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState(device);
}

class _DeviceScreenState extends ScreenState<DeviceScreen, String> with TickerProviderStateMixin {
  _DeviceScreenState(Device device) : super(title: "${device.name}", withDrawer: false);

  final _controller = MapWidgetController();

  Device _device;
  StreamGroup<dynamic> _group;
  StreamSubscription<Device> _onMoved;

  /// Use current device name
  String get title => _device?.name;

  @override
  void initState() {
    super.initState();
    routeWriter = false;
    routeData = widget?.device?.uuid;
    _device = widget.device;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_onMoved != null) _onMoved.cancel();
    if (isCommander || isSelected) {
      _onMoved = context.read<DeviceBloc>().onMoved(_device).listen(_onMove);
    }
  }

  @override
  void dispose() {
    _group?.close();
    _onMoved?.cancel();
    _controller?.cancel();
    _group = null;
    _onMoved = null;
    super.dispose();
  }

  bool get isSelected => context.read<OperationBloc>().isSelected;
  bool get isCommander => context.read<OperationBloc>().isAuthorizedAs(UserRole.commander);

  @override
  List<Widget> buildAppBarActions() {
    return isCommander
        ? [
            DeviceActionGroup(
              device: _device,
              onMessage: showMessage,
              type: ActionGroupType.popupMenuButton,
              onDeleted: () => Navigator.pop(context),
              unit: context.read<TrackingBloc>().units.find(_device),
              onChanged: (device) => setState(() => _device = device),
              personnel: context.read<TrackingBloc>().personnels.find(_device),
            )
          ]
        : [];
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DeviceBloc>().load();
      },
      child: ListView(
        padding: const EdgeInsets.all(DeviceScreen.SPACING),
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          StreamBuilder<Device>(
            initialData: _device,
            stream: context.read<DeviceBloc>().onChanged(_device, skipPosition: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: Text("Ingen data"));
              if (snapshot.data is Device) {
                _device = snapshot.data;
              }
              final unit = context.read<TrackingBloc>().units.find(_device);
              final personnel = context.read<TrackingBloc>().personnels.find(
                    _device,
                  );
              final person = personnel?.person ??
                  context.read<AffiliationBloc>().persons.findUser(
                        _device.networkId,
                      );
              return DeviceWidget(
                unit: unit,
                person: person,
                device: _device,
                withHeader: false,
                withActions: false,
                personnel: personnel,
                onMessage: showMessage,
                controller: _controller,
                withMap: isCommander || isSelected,
                onDeleted: () => Navigator.pop(context),
                onGoto: (point) => jumpToPoint(context, center: point),
                onChanged: (device) => setState(() => _device = device),
                tracking: context.read<TrackingBloc>().trackings[unit?.tracking?.uuid],
              );
            },
          ),
        ],
      ),
    );
  }

  LatLng toCenter(Point location) {
    return location != null ? toLatLng(location) : null;
  }

  void _onMove(Device event) {
    final center = toCenter(event?.position?.geometry);
    if (center != null) {
      _controller.animatedMove(center, _controller.zoom, this);
    }
  }
}
