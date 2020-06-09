import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'debug_data_screen.dart';
import 'debug_location_screen.dart';

class DebugScreen extends StatefulWidget {
  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Feilsøkning"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.storage),
              title: Text('Data'),
              subtitle: Text('Feilsøke data lagret lokalt'),
              onTap: () async {
                Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                  return DebugDataScreen();
                }));
              },
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text('Posisjon og sporing'),
              subtitle: Text('Feilsøke problemer med posisjon og sporing'),
              onTap: () async {
                Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                  return DebugLocationScreen();
                }));
              },
            ),
          ],
        ),
      ),
    );
  }
}
