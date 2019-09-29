import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/unit_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UnitScreen extends Screen<_UnitScreenState> {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 4.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Unit unit;

  const UnitScreen({Key key, @required this.unit}) : super(key: key);

  @override
  _UnitScreenState createState() => _UnitScreenState(unit);
}

class _UnitScreenState extends ScreenState<UnitScreen> {
  _UnitScreenState(Unit unit) : super(title: "${unit.name}", withDrawer: false);

  UserBloc _userBloc;
  UnitBloc _unitBloc;
  TrackingBloc _trackingBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            StreamBuilder<Unit>(
              initialData: widget.unit,
              stream: _unitBloc.changes(widget.unit),
              builder: (context, snapshot) {
                var unit = snapshot.data;
                return snapshot.hasData
                    ? ListView(
                        padding: const EdgeInsets.all(UnitScreen.SPACING),
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildMapTile(context, unit),
                          UnitInfoPanel(
                            unit: unit,
                            bloc: _trackingBloc,
                            withHeader: false,
                            onMessage: showMessage,
                          ),
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

  Widget _buildMapTile(BuildContext context, Unit unit) {
    final location = _trackingBloc.tracking[unit.tracking]?.location;
    final center = location != null ? toLatLng(location) : null;
    return Container(
      height: 240.0,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UnitScreen.CORNER),
          child: GestureDetector(
            child: IncidentMap(
              center: location != null ? toLatLng(location) : null,
              zoom: 15.0,
              interactive: false,
            ),
            onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
          ),
        ),
        elevation: UnitScreen.ELEVATION,
        borderRadius: BorderRadius.circular(UnitScreen.CORNER),
      ),
    );
  }
}
