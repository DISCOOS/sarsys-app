import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/user_screen.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:simple_gravatar/simple_gravatar.dart';

import 'descriptions.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = context.bloc<UserBloc>();
    final User user = userBloc.user;
    final isUnset = context.bloc<IncidentBloc>().isUnset;
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(context, userBloc),
          _buildIncidentListAction(context),
          Divider(),
          _buildMapAction(context),
          Divider(),
          _buildIncidentHeader(isUnset, context),
          _buildMyIncidentPageAction(isUnset, context),
          _buildMyUnitPageAction(isUnset, context),
          _buildMyPageAction(context),
          _buildMyHistoryAction(isUnset, context),
          Divider(),
//          _buildMissionsPageAction(isUnset, context),
          _buildUnitsPageAction(isUnset, context),
          _buildPersonnelsPageAction(isUnset, context),
          _buildDevicesPageAction(isUnset, context),
          Divider(),
          _buildSettingsAction(context),
          _buildLogoutAction(user, context, userBloc),
        ],
      ),
    );
  }

  ListTile _buildMissionsPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.assignment),
      title: Text('Oppdrag', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_MISSION_LIST);
      },
    );
  }

  ListTile _buildLogoutAction(User user, BuildContext context, UserBloc userBloc) {
    return ListTile(
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
          Navigator.pop(context);
          await userBloc.logout();
        }
      },
    );
  }

  ListTile _buildSettingsAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      title: Text('Innstillinger', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.popAndPushNamed(context, SettingsScreen.ROUTE);
      },
    );
  }

  ListTile _buildMyHistoryAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.history),
      title: Text('Min historikk', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_HISTORY);
      },
    );
  }

  ListTile _buildMyPageAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.account_box),
      title: Text('Min side', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_STATUS);
      },
    );
  }

  ListTile _buildMyUnitPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.supervised_user_circle),
      title: Text('Min enhet', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_UNIT);
      },
    );
  }

  ListTile _buildMyIncidentPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.warning),
      title: Text('Aksjon', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_INCIDENT);
      },
    );
  }

  ListTile _buildDevicesPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(MdiIcons.cellphoneBasic),
      title: Text('Apparater', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_DEVICE_LIST);
      },
    );
  }

  ListTile _buildPersonnelsPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.person),
      title: Text('Mannskap', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_PERSONNEL_LIST);
      },
    );
  }

  ListTile _buildUnitsPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.people),
      title: Text('Enheter', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_UNIT_LIST);
      },
    );
  }

  ListTile _buildIncidentHeader(bool isUnset, BuildContext context) {
    final selected = context.bloc<IncidentBloc>().selected;
    final labels = selected == null
        ? ['Velg en aksjon']
        : [
            '${selected.name ?? translateIncidentType(selected.type)}',
            '${selected.reference ?? '<ingen referanse>'}',
          ];

    return ListTile(
      enabled: !isUnset,
      title: Wrap(
        children: labels
            .map((label) => Text(
                  label,
                  style: Theme.of(context).textTheme.bodyText2,
                ))
            .toList(),
      ),
      trailing: isUnset
          ? null
          : RaisedButton.icon(
              icon: Icon(Icons.assignment_turned_in),
              label: Text("Forlat"),
              onPressed: () {
                Navigator.pop(context);
                leaveIncident();
              },
            ),
    );
  }

  ListTile _buildMapAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.map),
      title: Text('Kart', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, MapScreen.ROUTE);
      },
    );
  }

  ListTile _buildIncidentListAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.format_list_bulleted),
      title: Text('Aksjoner', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, IncidentsScreen.ROUTE);
      },
    );
  }

  Stack _buildHeader(BuildContext context, UserBloc bloc) {
    final user = bloc.user;
    final gravatar = Gravatar(user.email);
    final url = gravatar.imageUrl(
      size: 100,
      defaultImage: GravatarImage.mp,
      fileExtension: true,
    );
    final avatar = Image.network(url);
    final roles = user.roles.toList();
    roles.sort((UserRole e1, UserRole e2) => e1.index - e2.index);
    return Stack(
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
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: FractionallySizedBox(
                widthFactor: 0.70,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _buildSecurityState(context, bloc),
                    _buildUserRoles(context, roles),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRoles(BuildContext context, List<UserRole> roles) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Chip(
        padding: EdgeInsets.only(right: 4.0),
        labelPadding: EdgeInsets.only(left: 8.0),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              (roles.isEmpty ? ['Ingen roller'] : roles.map(translateUserRoleAbbr)).join('/'),
              style: TextStyle(color: Colors.white38),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(
                Icons.info_outline,
                color: Colors.white24,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
      ),
      onTap: () {
        alert(
          context,
          title: "Roller og tilgangsstyring",
          content: UserRolesDescription(),
        );
      },
    );
  }

  GestureDetector _buildSecurityState(BuildContext context, UserBloc bloc) {
    return GestureDetector(
      child: Chip(
        padding: EdgeInsets.only(right: 4.0),
        labelPadding: EdgeInsets.only(left: 8.0),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${bloc.user.isTrusted ? translateSecurityMode(bloc.securityMode) : 'Begrenset'}',
              style: TextStyle(color: Colors.white38),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(
                Icons.info_outline,
                color: Colors.white24,
              ),
            )
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
      ),
      onTap: () {
        alert(
          context,
          title: "Bruksmodus og sikkerhet",
          content: bloc.isShared
              ? SecurityModeSharedDescription()
              : SecurityModePersonalDescription(untrusted: bloc.user.isUntrusted),
        );
      },
    );
  }
}
