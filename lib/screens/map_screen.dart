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
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _settingModalBottomSheet(context);
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
      onMessage: _showMessage,
      onPrompt: (title, message) => prompt(context, title, message),
      onOpenDrawer: () => _scaffoldKey.currentState.openDrawer(),
    );
  }

  void _settingModalBottomSheet(context) {
    final style = Theme.of(context).textTheme.title;
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.only(bottom: 56.0),
            child: Wrap(
              children: <Widget>[
                ListTile(title: Text("Opprett", style: style)),
                Divider(),
                ListTile(
                    leading: Icon(Icons.timeline),
                    title: Text('Spor', style: style),
                    onTap: () {
                      Navigator.pop(context);
                    }),
                ListTile(
                  leading: Icon(Icons.add_location),
                  title: Text('Markering', style: style),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        });
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