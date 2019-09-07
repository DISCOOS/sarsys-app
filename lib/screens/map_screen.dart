import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  final LatLng center;
  final Incident incident;

  const MapScreen({Key key, this.center, this.incident}) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _showFAB = true;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: _showFAB
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

  Widget _buildMap() {
    return IncidentMap(
      center: widget.center,
      incident: widget.incident,
      withSearch: true,
      withControls: true,
      withLocation: true,
      withScaleBar: true,
      withCoordsPanel: true,
      onMessage: _showMessage,
      onToolChange: (tool) => setState(() {
        _showFAB = !tool.active;
      }),
      onOpenDrawer: () => _scaffoldKey.currentState.openDrawer(),
      onPrompt: (title, message) => prompt(context, title, message),
    );
  }

  void _showCreateItemSheet(context) {
    final style = Theme.of(context).textTheme.title;
    final bloc = BlocProvider.of<IncidentBloc>(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(builder: (context, state) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return DraggableScrollableSheet(
              expand: false,
              builder: (context, controller) {
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
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) => UnitEditor(),
                          );
                        },
                      ),
                    ListTile(
                      dense: landscape,
                      leading: Icon(Icons.warning),
                      title: Text('Hendelse', style: style),
                      onTap: () async {
                        Navigator.pop(context);
                        final incident = await showDialog(
                          context: context,
                          builder: (context) => IncidentEditor(),
                        );
                        if (incident != null) {
                          Navigator.pushReplacementNamed(
                            context,
                            'map',
                            arguments: {
                              "incident": incident,
                              "center": toLatLng(incident.ipp),
                            },
                          );
                        }
                      },
                    ),
                  ],
                );
              });
        });
      },
    );
  }

  void _showMessage(String message, {String action = "OK", VoidCallback onPressed}) {
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
