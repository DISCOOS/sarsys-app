import 'dart:async';

import 'package:SarSys/features/incident/presentation/blocs/incident_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/features/incident/domain/usecases/incident_user_cases.dart';
import 'package:SarSys/usecase/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:SarSys/screens/screen.dart';

import 'package:SarSys/widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  static const ROUTE = 'map';

  final LatLng center;
  final Incident incident;
  final LatLngBounds fitBounds;
  final FitBoundsOptions fitBoundOptions;

  const MapScreen({
    Key key,
    this.center,
    this.fitBounds,
    this.fitBoundOptions,
    this.incident,
  }) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends RouteWriter<MapScreen, String> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapWidgetController();

  bool _showFAB = true;

  bool _unloaded = false;
  StreamSubscription<IncidentState> _subscription;
  Incident get incident => _unloaded ? null : widget.incident;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenForIncidentStates();
  }

  /// Initialize blocs and restart app after blocs are rebuilt
  void _listenForIncidentStates() {
    _subscription?.cancel();
    _subscription = context.bloc<IncidentBloc>().listen((state) {
      setState(() {
        _unloaded = state.shouldUnload(widget.incident?.uuid);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: _showFAB && context.bloc<UserBloc>()?.user?.isCommander == true
          ? FloatingActionButton(
              onPressed: () {
                _showCreateItemSheet(context);
              },
              child: Icon(Icons.add),
              elevation: 2.0,
            )
          : Container(),
      body: _buildMap(),
    );
  }

  Widget _buildMap() => MapWidget(
        incident: incident,
        center: widget.center,
        fitBounds: widget.fitBounds,
        fitBoundOptions: widget.fitBoundOptions,
        mapController: _mapController,
        readZoom: true,
        readCenter: widget.center == null,
        readLayers: true,
        withRead: true,
        withWrite: true,
        withSearch: true,
        withControls: true,
        withControlsZoom: true,
        withControlsTool: true,
        withControlsLayer: true,
        withControlsBaseMap: true,
        withControlsLocateMe: true,
        withScaleBar: true,
        withCoordsPanel: true,
        onMessage: _showMessage,
        onToolChange: (tool) => setState(() {
          _showFAB = !tool.active();
        }),
        onOpenDrawer: () => _scaffoldKey.currentState.openDrawer(),
      );

  void _showCreateItemSheet(BuildContext context) {
    final style = Theme.of(context).textTheme.headline6;
    final isSelected = context.bloc<IncidentBloc>().isSelected;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(builder: (_, state) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return DraggableScrollableSheet(
              expand: false,
              builder: (_, controller) {
                return ListView(
                  padding: EdgeInsets.only(bottom: 56.0),
                  children: <Widget>[
                    ListTile(title: Text("Opprett", style: style)),
                    Divider(),
                    if (isSelected)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.group_add),
                        title: Text('Enhet', style: style),
                        onTap: () async {
                          await createUnit(
                            position: toPosition(_mapController.center),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    if (!isSelected)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.warning),
                        title: Text('Aksjon', style: style),
                        onTap: () async {
                          final result = await createIncident(
                            ipp: toPoint(_mapController.center),
                          );
                          result.fold((_) => null, (incident) => jumpToIncident(context, incident));
                          Navigator.pop(context);
                        },
                      ),
                  ],
                );
              });
        });
      },
    );
  }

  void _showMessage(
    String message, {
    String action = "OK",
    VoidCallback onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildAction(action, () {
        if (onPressed != null) onPressed();
        _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  Widget _buildAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
