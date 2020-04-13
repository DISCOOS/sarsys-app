import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/usecase/unit.dart';
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
  final _mapController = IncidentMapController();

  bool _showFAB = true;

  @override
  Widget build(BuildContext context) {
    final userBloc = BlocProvider.of<UserBloc>(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: _showFAB && userBloc?.user?.isCommander == true
          ? FloatingActionButton(
              onPressed: () {
                _showCreateItemSheet(context);
              },
              child: Icon(Icons.add),
              elevation: 2.0,
            )
          : Container(),
      body: _buildMap(),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildMap() => MapWidget(
        center: widget.center,
        incident: widget.incident,
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

  void _showCreateItemSheet(context) {
    final style = Theme.of(context).textTheme.title;
    final bloc = BlocProvider.of<IncidentBloc>(context);
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
                    if (!bloc.isUnset)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.group_add),
                        title: Text('Enhet', style: style),
                        onTap: () async {
                          await createUnit(
                            context,
                            point: toPoint(_mapController.center),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    if (bloc.isUnset)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.warning),
                        title: Text('Aksjon', style: style),
                        onTap: () async {
                          final result = await createIncident(
                            context,
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
}
