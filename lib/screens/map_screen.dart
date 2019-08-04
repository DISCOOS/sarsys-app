import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  final LatLng center;

  const MapScreen({Key key, this.center}) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateItemSheet(context);
        },
        child: Icon(Icons.add),
        elevation: 2.0,
      ),
      body: _buildMap(),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildMap() {
    return IncidentMap(
      center: widget.center,
      withSearch: true,
      withControls: true,
      withLocation: true,
      withCoordsPanel: true,
      onMessage: _showMessage,
      onPrompt: (title, message) => prompt(context, title, message),
      onOpenDrawer: () => _scaffoldKey.currentState.openDrawer(),
    );
  }

  void _showCreateItemSheet(context) {
    final style = Theme.of(context).textTheme.title;
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
                        }),
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
