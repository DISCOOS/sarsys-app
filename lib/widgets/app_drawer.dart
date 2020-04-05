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
    final avatar = Image.asset("assets/images/avatar-male.png");
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(
              "${user?.fullName}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user.email,
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            currentAccountPicture: CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).accentColor,
              child: avatar,
            ),
//            otherAccountsPictures: <Widget>[
//              GestureDetector(
//                child: CircleAvatar(
//                  backgroundColor: Theme.of(context).accentColor,
//                  child: Icon(Icons.person_add),
//                ),
//                onTap: () {},
//              )
//            ],
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: Text('Velg hendelse', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'incident/list');
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
              Navigator.pushReplacementNamed(context, 'unit/list');
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.person),
            title: Text('Mannskap', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'personnel/list');
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(MdiIcons.cellphoneBasic),
            title: Text('Apparater', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, 'device/list');
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: Text('Logg av', style: TextStyle(fontSize: 14)),
            onTap: () async {
              await userBloc.logout();
              Navigator.pushReplacementNamed(context, 'login');
            },
          ),
          ListTile(
            leading: const Icon(Icons.phonelink_lock),
            title: Text('Endre pin', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, 'change/pin');
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
