import 'package:flutter/material.dart';
import '../services/UserService.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final UserService userService = UserService();
    return Drawer(
        child: ListView(
            // Important: Remove any padding from the ListView.
            padding: EdgeInsets.zero,
            children: <Widget>[
          Container(
            child: Text("SarSys", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            padding: EdgeInsets.only(
                top: mediaQuery.padding.top + 16.0,
                bottom: mediaQuery.padding.bottom + 0.0),
            decoration: BoxDecoration(
              color: Colors.grey[800],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted ),
            title: Text('Velg hendelse'),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'incidentlist');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: Text('Kart'),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'map');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('Enheter'),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'map');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Logg ut'),
            onTap: () async {
              await userService.logout();
              Navigator.pushReplacementNamed(context, 'login');
            },
          ),

        ]));
  }
}
