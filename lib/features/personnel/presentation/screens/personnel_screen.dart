

import 'dart:async';

import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';
import 'package:SarSys/core/extensions.dart';

class PersonnelScreen extends Screen<_PersonnelScreenState> {
  static const ROUTE = 'personnel';

  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Personnel personnel;

  const PersonnelScreen({Key? key, required this.personnel}) : super(key: key);

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

  final MapWidgetController _controller = MapWidgetController();

  late Personnel _personnel;
  StreamGroup<dynamic>? _group;
  StreamSubscription<Tracking?>? _onMoved;

  /// Use current personnel name
  String? get title => _personnel?.name;

  @override
  void initState() {
    super.initState();

    _personnel = widget.personnel;
    routeData = widget?.personnel?.uuid;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group!.close();
    _group = StreamGroup.broadcast()
      ..add(context.read<PersonnelBloc>().onChanged(widget.personnel))
      ..add(context.read<TrackingBloc>().onChanged(widget.personnel?.tracking?.uuid, skipPosition: true));
    if (_onMoved != null) _onMoved!.cancel();
    _onMoved = context.read<TrackingBloc>().onMoved(widget.personnel?.tracking?.uuid).listen(_onMove);
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

  bool get isCommander => context.read<OperationBloc>().isAuthorizedAs(UserRole.commander);

  @override
  List<Widget> buildAppBarActions() {
    return isCommander
        ? [
            PersonnelActionGroup(
              personnel: _personnel,
              onMessage: showMessage,
              onDeleted: () => Navigator.pop(context),
              type: ActionGroupType.popupMenuButton,
              unit: context.read<UnitBloc>().repo.findPersonnel(_personnel!.uuid).firstOrNull,
              onChanged: (personnel) => setState(() => _personnel = personnel),
            )
          ]
        : [];
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PersonnelBloc>().load();
      },
      child: ListView(
        padding: const EdgeInsets.all(PersonnelScreen.SPACING),
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          StreamBuilder(
            initialData: _personnel,
            stream: _group!.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: Text("Ingen data"));
              }
              if (snapshot.data is Personnel) {
                _personnel = snapshot.data as Personnel;
              }
              return _build(context);
            },
          ),
        ],
      ),
    );
  }

  PersonnelWidget _build(BuildContext context) => PersonnelWidget(
        withMap: true,
        withHeader: false,
        withActions: false,
        personnel: _personnel,
        controller: _controller,
        devices: context.read<TrackingBloc>().devices(_personnel!.tracking?.uuid),
        tracking: context.read<TrackingBloc>().trackings[_personnel!.tracking?.uuid],
        unit: context.read<UnitBloc>().repo.findPersonnel(_personnel!.uuid).firstOrNull,
        onGoto: (point) => jumpToPoint(context, center: point),
        onMessage: showMessage,
        onDeleted: () => Navigator.pop(context),
        onChanged: (personnel) => setState(() => _personnel = personnel),
      );

  LatLng? toCenter(Tracking? event) {
    final point = event?.position?.geometry;
    return point != null ? toLatLng(point) : null;
  }

  void _onMove(Tracking? event) {
    if (mounted) {
      final center = toCenter(event);
      if (center != null) {
        _controller.animatedMove(center, _controller.zoom, this);
      }
    }
  }
}
