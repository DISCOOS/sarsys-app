import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:async/async.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';

class PersonnelScreen extends Screen<_PersonnelScreenState> {
  static const ROUTE = 'personnel';

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
  _PersonnelScreenState(Personnel personnel)
      : super(
          title: "${personnel.name}",
          withDrawer: false,
          routeWriter: false,
        );

  final _controller = IncidentMapController();

  Personnel _personnel;
  StreamGroup<dynamic> _group;
  StreamSubscription<Tracking> _onMoved;

  /// Use current personnel name
  String get title => _personnel?.name;

  @override
  void initState() {
    super.initState();

    _personnel = widget.personnel;
    routeData = widget?.personnel?.uuid;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<PersonnelBloc>().onChanged(widget.personnel))
      ..add(context.bloc<TrackingBloc>().changes(widget.personnel?.tracking?.uuid));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = context.bloc<TrackingBloc>().changes(widget.personnel?.tracking?.uuid).listen(_onMove);
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
                if (!snapshot.hasData) return Center(child: Text("Ingen data"));
                if (snapshot.data is Personnel) {
                  _personnel = snapshot.data;
                }
                return ListView(
                  padding: const EdgeInsets.all(PersonnelScreen.SPACING),
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildMapTile(context, _personnel),
                    _buildInfoPanel(context),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PersonnelWidget _buildInfoPanel(BuildContext context) => PersonnelWidget(
        personnel: _personnel,
        tracking: context.bloc<TrackingBloc>().tracking[_personnel.tracking.uuid],
        devices: context.bloc<TrackingBloc>().devices(_personnel.tracking.uuid),
        withHeader: false,
        withActions: context.bloc<UserBloc>().user.isCommander,
        organization: FleetMapService().fetchOrganization(Defaults.orgId),
        onMessage: showMessage,
        onDelete: () => Navigator.pop(context),
        onGoto: (point) => jumpToPoint(context, center: point),
        onChanged: (personnel) => setState(() => _personnel = personnel),
      );

  Widget _buildMapTile(BuildContext context, Personnel personnel) {
    final center = toCenter(context.bloc<TrackingBloc>().tracking[personnel.tracking.uuid]);
    return Material(
      elevation: PersonnelScreen.ELEVATION,
      borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
      child: Container(
        height: 240.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
          child: GestureDetector(
            child: MapWidget(
              center: center,
              zoom: 16.0,
              interactive: false,
              withPOIs: false,
              withUnits: false,
              withRead: true,
              withControls: true,
              withControlsZoom: true,
              withControlsOffset: 16.0,
              showRetired: PersonnelStatus.Retired == personnel.status,
              showLayers: [
                MapWidgetState.LAYER_PERSONNEL,
                MapWidgetState.LAYER_TRACKING,
              ],
              mapController: _controller,
            ),
            onTap: () => center == null
                ? Navigator.pushReplacementNamed(context, MapScreen.ROUTE)
                : jumpToLatLng(context, center: center),
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
