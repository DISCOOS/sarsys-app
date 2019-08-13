import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = BlocProvider.of<UserBloc>(context);
    final isUnset = BlocProvider.of<IncidentBloc>(context).isUnset;
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          SizedBox(
            height: 120.0,
            child: DrawerHeader(
              child: Text("SarSys", style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white)),
              decoration: BoxDecoration(
                color: Colors.grey[800],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: Text('Velg hendelse', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'incidents');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: Text('Kart', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'map');
            },
          ),
          Divider(),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.warning),
            title: Text('Hendelse', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'incident');
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.people),
            title: Text('Enheter', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'units');
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.device_unknown),
            title: Text('Terminaler', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'terminals');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Logg ut', style: TextStyle(fontSize: 14)),
            onTap: () async {
              await userBloc?.logout();
              Navigator.popAndPushNamed(context, 'login');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('Innstillinger', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'settings');
            },
          ),
        ],
      ),
    );
  }
}
