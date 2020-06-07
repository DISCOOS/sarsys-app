import 'dart:async';

import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/widgets/action_group.dart';
import 'package:async/async.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';

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
    _onMoved = context.bloc<DeviceBloc>().onChanged(_device).listen(_onMove);
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

  bool get isCommander => context.bloc<UserBloc>().user?.isCommander == true;

  @override
  List<Widget> buildAppBarActions() {
    return isCommander
        ? [
            DeviceActionGroup(
              device: _device,
              onMessage: showMessage,
              type: ActionGroupType.popupMenuButton,
              onDeleted: () => Navigator.pop(context),
              unit: context.bloc<TrackingBloc>().units.find(_device),
              onChanged: (device) => setState(() => _device = device),
              personnel: context.bloc<TrackingBloc>().personnels.find(_device),
            )
          ]
        : [];
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: ListView(
          padding: const EdgeInsets.all(DeviceScreen.SPACING),
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            _buildMapTile(context, _device),
            StreamBuilder<Device>(
              initialData: _device,
              stream: context.bloc<DeviceBloc>().onChanged(_device),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: Text("Ingen data"));
                if (snapshot.data is Device) {
                  _device = snapshot.data;
                }
                final unit = context.bloc<TrackingBloc>().units.find(_device);
                final personnel = context.bloc<TrackingBloc>().personnels.find(_device);
                return _buildInfoPanel(unit, personnel, context);
              },
            ),
          ],
        ),
      ),
    );
  }

  DeviceWidget _buildInfoPanel(Unit unit, Personnel personnel, BuildContext context) => DeviceWidget(
        unit: unit,
        device: _device,
        withHeader: false,
        withActions: false,
        personnel: personnel,
        onMessage: showMessage,
        onDeleted: () => Navigator.pop(context),
        onGoto: (point) => jumpToPoint(context, center: point),
        onChanged: (device) => setState(() => _device = device),
        organization: FleetMapService().fetchOrganization(Defaults.orgId),
        tracking: context.bloc<TrackingBloc>().trackings[unit?.tracking?.uuid],
      );

  Widget _buildMapTile(BuildContext context, Device device) {
    final center = toCenter(device.position?.geometry);
    return Material(
      elevation: DeviceScreen.ELEVATION,
      borderRadius: BorderRadius.circular(DeviceScreen.CORNER),
      child: Container(
        height: 240.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DeviceScreen.CORNER),
          child: GestureDetector(
            child: MapWidget(
              key: ObjectKey(device.uuid),
              center: center,
              zoom: 16.0,
              interactive: false,
              withUnits: false,
              withDevices: true,
              withPersonnel: false,
              withTracking: false,
              withRead: true,
              withWrite: true,
              withControls: true,
              withControlsZoom: true,
              withControlsLayer: true,
              withControlsBaseMap: true,
              withControlsOffset: 16.0,
              showLayers: [
                MapWidgetState.LAYER_POI,
                MapWidgetState.LAYER_DEVICE,
                MapWidgetState.LAYER_SCALE,
              ],
              mapController: _controller,
            ),
            onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
          ),
        ),
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
