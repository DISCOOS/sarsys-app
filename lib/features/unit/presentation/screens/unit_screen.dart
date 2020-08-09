import 'dart:async';

import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:async/async.dart';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    _group?.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UnitBloc>().onChanged(widget.unit?.uuid))
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
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: StreamBuilder(
          initialData: _unit,
          stream: _group.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: Text("Ingen data"));
            if (snapshot.data is Unit) {
              _unit = snapshot.data;
            }
            final tracking = context.bloc<TrackingBloc>().trackings[_unit.tracking.uuid];
            return _build(context, tracking);
          },
        ),
      ),
    );
  }

  UnitWidget _build(
    BuildContext context,
    Tracking tracking,
  ) =>
      UnitWidget(
        unit: _unit,
        withMap: true,
        withHeader: false,
        withActions: false,
        tracking: tracking,
        onMessage: showMessage,
        controller: _controller,
        onDeleted: () => Navigator.pop(context),
        onChanged: (unit) => setState(() => _unit = unit),
        onGoto: (point) => jumpToPoint(context, center: point),
        devices: context.bloc<TrackingBloc>().devices(tracking?.uuid),
      );

  void _onMove(Tracking tracking) {
    if (mounted) {
      final center = tracking?.position?.toLatLng();
      if (center != null) {
        _controller.animatedMove(center, _controller.zoom, this);
      }
    }
  }
}
