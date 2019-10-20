import 'dart:async';
import 'dart:math';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:async/async.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/personnel_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/map/map_controls.dart';
import 'package:latlong/latlong.dart';

class PersonnelScreen extends Screen<_PersonnelScreenState> {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Personnel personnel;

  const PersonnelScreen({Key key, @required this.personnel}) : super(key: key);

  @override
  _PersonnelScreenState createState() => _PersonnelScreenState(personnel);
}

class _PersonnelScreenState extends ScreenState<PersonnelScreen, String> with TickerProviderStateMixin {
  _PersonnelScreenState(Personnel personnel) : super(title: "${personnel.name}", withDrawer: false);

  final _controller = IncidentMapController();

  Personnel _personnel;
  UserBloc _userBloc;
  PersonnelBloc _personnelBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;
  StreamSubscription<Tracking> _onMoved;

  /// Use current personnel name
  String get title => _personnel?.name;

  @override
  void initState() {
    super.initState();
    writeEnabled = false;
    _personnel = widget.personnel;
    id = widget?.personnel?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(_personnelBloc.changes(widget.personnel))
      ..add(_trackingBloc.changes(widget.personnel?.tracking));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = _trackingBloc.changes(widget.personnel?.tracking).listen(_onMove);
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
              initialData: _personnel,
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.data is Personnel) _personnel = snapshot.data;
                final tracking = _trackingBloc.tracking[_personnel.tracking];
                return snapshot.hasData
                    ? ListView(
                        padding: const EdgeInsets.all(PersonnelScreen.SPACING),
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildMapTile(context, _personnel),
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

  PersonnelInfoPanel _buildInfoPanel(Tracking tracking, BuildContext context) {
    return PersonnelInfoPanel(
      personnel: _personnel,
      tracking: tracking,
      devices: tracking?.devices
              ?.map((id) => _trackingBloc.deviceBloc.devices[id])
              ?.where((personnel) => personnel != null) ??
          {},
      withHeader: false,
      withActions: _userBloc.user?.isCommander,
      onMessage: showMessage,
      onChanged: (personnel) => setState(() => _personnel = personnel),
      organization: AssetsService().fetchOrganization(Defaults.organization),
      onComplete: (_) => Navigator.pop(context),
    );
  }

  Widget _buildMapTile(BuildContext context, Personnel personnel) {
    final center = toCenter(_trackingBloc.tracking[personnel.tracking]);
    return Material(
      elevation: PersonnelScreen.ELEVATION,
      borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
      child: Container(
        height: 240.0,
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
              child: GestureDetector(
                child: IncidentMap(
                  center: center,
                  zoom: 16.0,
                  interactive: false,
                  withPOIs: false,
                  withUnits: false,
                  usePersisted: false,
                  showLayers: [
                    IncidentMapState.PERSONNEL_LAYER,
                    IncidentMapState.TRACKING_LAYER,
                  ],
                  mapController: _controller,
                ),
                onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    var tracking = _trackingBloc.tracking[widget.personnel.tracking];
    return MapControls(
      top: 16.0,
      controls: [
        MapControl(
          icon: Icons.add,
          onPressed: () {
            if (tracking?.point != null) {
              var zoom = min(_controller.zoom + 1, Defaults.maxZoom);
              _controller.animatedMove(toCenter(tracking), zoom, this, milliSeconds: 250);
            }
          },
        ),
        MapControl(
          icon: Icons.remove,
          onPressed: () {
            if (tracking?.point != null) {
              var zoom = max(_controller.zoom - 1, Defaults.minZoom);
              _controller.animatedMove(toCenter(tracking), zoom, this, milliSeconds: 250);
            }
          },
        ),
      ],
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