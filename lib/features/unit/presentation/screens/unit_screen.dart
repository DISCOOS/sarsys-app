import 'dart:async';

import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/widgets/action_group.dart';
import 'package:async/async.dart';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';

class UnitScreen extends Screen<_UnitScreenState> {
  static const ROUTE = 'unit';
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

  final _controller = MapWidgetController();

  Unit _unit;
  StreamGroup<dynamic> _group;
  StreamSubscription<Tracking> _onMoved;

  /// Use current unit name
  String get title => _unit?.name;

  @override
  void initState() {
    super.initState();
    routeWriter = false;
    _unit = widget.unit;
    routeData = widget?.unit?.uuid;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UnitBloc>().onChanged(widget.unit))
      ..add(context.bloc<TrackingBloc>().onChanged(widget?.unit?.tracking?.uuid));
    if (_onMoved != null) _onMoved.cancel();
    _onMoved = context.bloc<TrackingBloc>().onChanged(widget?.unit?.tracking?.uuid).listen(_onMove);
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
            UnitActionGroup(
              unit: _unit,
              onMessage: showMessage,
              onDeleted: () => Navigator.pop(context),
              type: ActionGroupType.popupMenuButton,
              onChanged: (unit) => setState(() => _unit = unit),
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
          padding: const EdgeInsets.all(UnitScreen.SPACING),
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            _buildMapTile(context, _unit),
            StreamBuilder(
                initialData: _unit,
                stream: _group.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: Text("Ingen data"));
                  if (snapshot.data is Unit) {
                    _unit = snapshot.data;
                  }
                  final tracking = context.bloc<TrackingBloc>().trackings[_unit.tracking.uuid];
                  return _buildInfoPanel(tracking, context);
                }),
          ],
        ),
      ),
    );
  }

  UnitWidget _buildInfoPanel(Tracking tracking, BuildContext context) => UnitWidget(
        unit: _unit,
        withHeader: false,
        withActions: false,
        tracking: tracking,
        devices: tracking?.sources
            ?.map((source) => context.bloc<TrackingBloc>().deviceBloc.devices[source.uuid])
            ?.where((unit) => unit != null),
        onMessage: showMessage,
        onChanged: (unit) => setState(() => _unit = unit),
        onDeleted: () => Navigator.pop(context),
        onGoto: (point) => jumpToPoint(context, center: point),
      );

  Widget _buildMapTile(BuildContext context, Unit unit) {
    final center = toCenter(context.bloc<TrackingBloc>().trackings[unit.tracking.uuid]);
    return Material(
      elevation: UnitScreen.ELEVATION,
      borderRadius: BorderRadius.circular(UnitScreen.CORNER),
      child: Container(
        height: 240.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UnitScreen.CORNER),
          child: GestureDetector(
            child: MapWidget(
              key: ObjectKey(unit.uuid),
              center: center,
              zoom: 16.0,
              interactive: false,
              withUnits: true,
              withDevices: false,
              withPersonnel: false,
              withRead: true,
              withWrite: true,
              withControls: true,
              withControlsZoom: true,
              withControlsLayer: true,
              withControlsBaseMap: true,
              withControlsOffset: 16.0,
              showRetired: UnitStatus.Retired == unit.status,
              showLayers: [
                MapWidgetState.LAYER_POI,
                MapWidgetState.LAYER_PERSONNEL,
                MapWidgetState.LAYER_TRACKING,
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
