import 'dart:async';
import 'dart:math' as math;

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:async/async.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/device_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/map/map_controls.dart';
import 'package:latlong/latlong.dart';

class DeviceScreen extends Screen<_DeviceScreenState> {
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

class _DeviceScreenState extends ScreenState<DeviceScreen> with TickerProviderStateMixin {
  _DeviceScreenState(Device device) : super(title: "${device.name}", withDrawer: false);

  final _controller = IncidentMapController();

  Device _device;
  UserBloc _userBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;
  StreamSubscription<Device> _onMoved;

  /// Use current device name
  String get title => _device?.name;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    final unit = _trackingBloc.getUnitsByDeviceId()[_device.id];
    _group = StreamGroup.broadcast()..add(_deviceBloc.changes(_device))..add(_trackingBloc.changes(unit));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = _deviceBloc.changes(_device).listen(_onMove);
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

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            StreamBuilder(
              initialData: _device,
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.data is Device) _device = snapshot.data;
                final unit = _trackingBloc.getUnitsByDeviceId()[_device.id];
                return ListView(
                  padding: const EdgeInsets.all(DeviceScreen.SPACING),
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildMapTile(context, _device),
                    DeviceInfoPanel(
                      unit: unit,
                      device: _device,
                      tracking: _trackingBloc.tracking[unit?.tracking],
                      organization: AssetsService().fetchOrganization(Defaults.orgId),
                      withHeader: false,
                      withActions: _userBloc.user?.isCommander == true,
                      onMessage: showMessage,
                      onChanged: (device) => setState(() => _device = device),
                      onComplete: (_) => Navigator.pop(context),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTile(BuildContext context, Device device) {
    final center = toCenter(device.point);
    return Material(
      elevation: DeviceScreen.ELEVATION,
      borderRadius: BorderRadius.circular(DeviceScreen.CORNER),
      child: Container(
        height: 240.0,
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(DeviceScreen.CORNER),
              child: GestureDetector(
                child: IncidentMap(
                  center: center,
                  zoom: 16.0,
                  interactive: false,
                  withPOIs: false,
                  withUnits: false,
                  showLayers: [
                    IncidentMapState.DEVICE_LAYER,
                    IncidentMapState.TRACKING_LAYER,
                  ],
                  mapController: _controller,
                ),
                onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
              ),
            ),
            _buildControls(device),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Device device) {
    return MapControls(
      top: 16.0,
      controls: [
        MapControl(
          icon: Icons.add,
          onPressed: () {
            if (device?.point != null) {
              var zoom = math.min(_controller.zoom + 1, Defaults.maxZoom);
              _controller.animatedMove(
                toCenter(device?.point),
                zoom,
                this,
                milliSeconds: 250,
              );
            }
          },
        ),
        MapControl(
          icon: Icons.remove,
          onPressed: () {
            if (device?.point != null) {
              var zoom = math.max(_controller.zoom - 1, Defaults.minZoom);
              _controller.animatedMove(
                toCenter(device?.point),
                zoom,
                this,
                milliSeconds: 250,
              );
            }
          },
        ),
      ],
    );
  }

  LatLng toCenter(Point location) {
    return location != null ? toLatLng(location) : null;
  }

  void _onMove(Device event) {
    final center = toCenter(event?.point);
    if (center != null) {
      _controller.animatedMove(center, _controller.zoom, this);
    }
  }
}
