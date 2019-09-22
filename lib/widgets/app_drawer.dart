import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/User.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = BlocProvider.of<UserBloc>(context);
    final User user = userBloc.user;
    final isUnset = BlocProvider.of<IncidentBloc>(context).isUnset;
    final avatar = Image.asset("assets/images/avatar male.png");
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text("User ${user?.userId}"),
            accountEmail: Text(user?.roles?.map((role) => translateUserRole(role))?.join(", ")),
            decoration: BoxDecoration(
              color: Colors.grey[800],
            ),
            currentAccountPicture: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[600],
              child: avatar,
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
            leading: const Icon(MdiIcons.cellphoneBasic),
            title: Text('Apparater', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'devices');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Logg ut', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              userBloc?.logout();
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
