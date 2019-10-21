import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:async/async.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/unit_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';

class UnitScreen extends Screen<_UnitScreenState> {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Unit unit;

  const UnitScreen({Key key, @required this.unit}) : super(key: key);

  @override
  _UnitScreenState createState() => _UnitScreenState(unit);
}

class _UnitScreenState extends ScreenState<UnitScreen, String> with TickerProviderStateMixin {
  _UnitScreenState(Unit unit) : super(title: "${unit.name}", withDrawer: false);

  final _controller = IncidentMapController();

  Unit _unit;
  UserBloc _userBloc;
  UnitBloc _unitBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;
  StreamSubscription<Tracking> _onMoved;

  /// Use current unit name
  String get title => _unit?.name;

  @override
  void initState() {
    super.initState();
    writeEnabled = false;
    _unit = widget.unit;
    id = widget?.unit?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(_unitBloc.changes(widget.unit))
      ..add(_trackingBloc.changes(widget?.unit?.tracking));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = _trackingBloc.changes(widget?.unit?.tracking).listen(_onMove);
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
              initialData: _unit,
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.data is Unit) _unit = snapshot.data;
                final tracking = _trackingBloc.tracking[_unit.tracking];
                return snapshot.hasData
                    ? ListView(
                        padding: const EdgeInsets.all(UnitScreen.SPACING),
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildMapTile(context, _unit),
                          _buildInfoPanel(tracking, context),
                        ],
                      )
                    : Center(child: Text("Ingen data"));
              },
            ),
          ],
        ),
      ),
    );
  }

  UnitInfoPanel _buildInfoPanel(Tracking tracking, BuildContext context) {
    return UnitInfoPanel(
      unit: _unit,
      tracking: tracking,
      devices: tracking?.devices?.map((id) => _trackingBloc.deviceBloc.devices[id])?.where((unit) => unit != null),
      withHeader: false,
      withActions: _userBloc.user?.isCommander,
      onMessage: showMessage,
      onChanged: (unit) => setState(() => _unit = unit),
      onComplete: (_) => Navigator.pop(context),
    );
  }

  Widget _buildMapTile(BuildContext context, Unit unit) {
    final center = toCenter(_trackingBloc.tracking[unit.tracking]);
    return Material(
      elevation: UnitScreen.ELEVATION,
      borderRadius: BorderRadius.circular(UnitScreen.CORNER),
      child: Container(
        height: 240.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UnitScreen.CORNER),
          child: GestureDetector(
            child: IncidentMap(
              center: center,
              zoom: 16.0,
              interactive: false,
              withPOIs: false,
              withDevices: false,
              withRead: true,
              withControls: true,
              withControlsZoom: true,
              withControlsOffset: 16.0,
              showLayers: [
                IncidentMapState.UNIT_LAYER,
                IncidentMapState.TRACKING_LAYER,
              ],
              mapController: _controller,
            ),
            onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
          ),
        ),
      ),
    );
  }

  LatLng toCenter(Tracking event) {
    final location = event?.point;
    return location != null ? toLatLng(location) : null;
  }

  void _onMove(Tracking event) {
    if (mounted) {
      final center = toCenter(event);
      if (center != null) {
        _controller.animatedMove(center, _controller.zoom, this);
      }
    }
  }
}
