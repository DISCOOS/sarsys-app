import 'dart:async';

import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/domain/models/Tracking.dart';
import 'package:SarSys/core/presentation/screens/map_screen.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:async/async.dart';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/presentation/map/map_widget.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';
import 'package:SarSys/core/extensions.dart';

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

class _PersonnelScreenState extends ScreenState<PersonnelScreen, String>
    with TickerProviderStateMixin {
  _PersonnelScreenState(Personnel personnel)
      : super(
          title: "${personnel.name}",
          withDrawer: false,
          routeWriter: false,
        );

  final _controller = MapWidgetController();

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
      ..add(context
          .bloc<TrackingBloc>()
          .onChanged(widget.personnel?.tracking?.uuid));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = context
        .bloc<TrackingBloc>()
        .onChanged(widget.personnel?.tracking?.uuid)
        .listen(_onMove);
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
            PersonnelActionGroup(
              personnel: _personnel,
              onMessage: showMessage,
              onDeleted: () => Navigator.pop(context),
              type: ActionGroupType.popupMenuButton,
              unit: context
                  .bloc<UnitBloc>()
                  .repo
                  .findPersonnel(_personnel.uuid)
                  .firstOrNull,
              onChanged: (personnel) => setState(() => _personnel = personnel),
            )
          ]
        : [];
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return RefreshIndicator(
      onRefresh: () async {
        context.bloc<PersonnelBloc>().load();
      },
      child: ListView(
        padding: const EdgeInsets.all(PersonnelScreen.SPACING),
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          StreamBuilder(
              initialData: _personnel,
              stream: _group.stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: Text("Ingen data"));
                if (snapshot.data is Personnel) {
                  _personnel = snapshot.data;
                }
                return _buildMapTile(context, _personnel);
              }),
          _buildInfoPanel(context),
        ],
      ),
    );
  }

  PersonnelWidget _buildInfoPanel(BuildContext context) => PersonnelWidget(
        withHeader: false,
        withActions: false,
        personnel: _personnel,
        unit: context
            .bloc<UnitBloc>()
            .repo
            .findPersonnel(_personnel.uuid)
            .firstOrNull,
        tracking:
            context.bloc<TrackingBloc>().trackings[_personnel.tracking.uuid],
        devices: context.bloc<TrackingBloc>().devices(_personnel.tracking.uuid),
        onGoto: (point) => jumpToPoint(context, center: point),
        onMessage: showMessage,
        onDeleted: () => Navigator.pop(context),
        onChanged: (personnel) => setState(() => _personnel = personnel),
      );

  Widget _buildMapTile(BuildContext context, Personnel personnel) {
    final center = toCenter(
        context.bloc<TrackingBloc>().trackings[personnel.tracking.uuid]);
    return Material(
      elevation: PersonnelScreen.ELEVATION,
      borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
      child: Container(
        height: 240.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PersonnelScreen.CORNER),
          child: GestureDetector(
            child: MapWidget(
              key: ObjectKey(personnel.uuid),
              center: center,
              zoom: 16.0,
              interactive: false,
              withUnits: false,
              withDevices: false,
              withPersonnel: true,
              withRead: true,
              withWrite: true,
              withControls: true,
              withControlsZoom: true,
              withControlsLayer: true,
              withControlsBaseMap: true,
              withControlsOffset: 16.0,
              showRetired: PersonnelStatus.retired == personnel.status,
              showLayers: [
                MapWidgetState.LAYER_POI,
                MapWidgetState.LAYER_PERSONNEL,
                MapWidgetState.LAYER_TRACKING,
                MapWidgetState.LAYER_SCALE,
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
    final point = event?.position?.geometry;
    return point != null ? toLatLng(point) : null;
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
