import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:simple_gravatar/simple_gravatar.dart';

import 'descriptions.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = BlocProvider.of<UserBloc>(context);
    final User user = userBloc.user;
    final isUnset = BlocProvider.of<IncidentBloc>(context).isUnset;
    final config = BlocProvider.of<AppConfigBloc>(context).config;
    var gravatar = Gravatar(user.email);
    var url = gravatar.imageUrl(
      size: 100,
      defaultImage: GravatarImage.mp,
      fileExtension: true,
    );
    final avatar = Image.network(url);
    final roles = user.roles.toList();
    roles.sort((UserRole e1, UserRole e2) => e1.index - e2.index);
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          Stack(
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
                  backgroundImage: avatar.image,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                    child: FractionallySizedBox(
                      widthFactor: 0.55,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          GestureDetector(
                            child: Chip(
                              padding: EdgeInsets.zero,
                              label: Text(
                                '${translateSecurityMode(config.securityMode)} '
                                '${user.isTrusted ? '' : '(begrenset)'}',
                                style: TextStyle(color: Colors.white38),
                              ),
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                            ),
                            onTap: () {
                              alert(
                                context,
                                title: "Bruksmodus og sikkerhet",
                                content: userBloc.isShared
                                    ? SecurityModeSharedDescription()
                                    : SecurityModePersonalDescription(untrusted: user.isUntrusted),
                              );
                            },
                          ),
                          Text(
                            roles.isEmpty ? 'Ingen roller' : roles.map(translateUserRole).join(', '),
                            style: TextStyle(color: Colors.white38),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: Text('Aksjoner', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, IncidentsScreen.ROUTE);
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: Text('Kart', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, MapScreen.ROUTE);
            },
          ),
          Divider(),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.warning),
            title: Text('Hendelse', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_INCIDENT);
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.people),
            title: Text('Enheter', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_UNIT_LIST);
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(Icons.person),
            title: Text('Mannskap', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_PERSONNEL_LIST);
            },
          ),
          ListTile(
            enabled: !isUnset,
            leading: const Icon(MdiIcons.cellphoneBasic),
            title: Text('Apparater', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_DEVICE_LIST);
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Logg av', style: TextStyle(fontSize: 14)),
            onTap: () async {
              // As a security precaution, security information
              // for users from untrusted domains are automatically
              // deleted. Notify user about this before logging out
              final answer = user.isTrusted ||
                  await prompt(
                    context,
                    'Bekreftelse',
                    'Du er innlogget med en bruker som krever at pinkoden slettes ved utlogging. Vil du logge ut?',
                  );

              if (answer) {
                await userBloc.logout();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.phonelink_lock),
            title: Text('Endre pin', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.popAndPushNamed(
                context,
                LoginScreen.ROUTE_CHANGE_PIN,
                arguments: {'popOnClose': true},
              );
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('Innstillinger', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.popAndPushNamed(context, SettingsScreen.ROUTE);
            },
          ),
        ],
      ),
    );
  }
}
