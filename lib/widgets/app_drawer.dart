import 'package:SarSys/blocs/user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = BlocProvider.of<UserBloc>(context);
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
              Navigator.pushNamed(context, 'incidents');
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
            leading: const Icon(Icons.warning),
            title: Text('Hendelse', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'incident');
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: Text('Plan', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'plan');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Logg ut', style: TextStyle(fontSize: 14)),
            onTap: () async {
              userBloc
                  .logout()
                  .state
                  .where((state) => state is UserUnset)
                  .listen((_) => {Navigator.pushReplacementNamed(context, 'login')});
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('Systeminnstillinger', style: TextStyle(fontSize: 14)),
            onTap: () async {
              PermissionHandler().openAppSettings();
            },
          ),
        ],
      ),
    );
  }
}
