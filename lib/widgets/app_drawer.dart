import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:simple_gravatar/simple_gravatar.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/features/settings/presentation/screens/settings_screen.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/utils/ui_utils.dart';

import 'descriptions.dart';

class AppDrawer extends StatefulWidget {
  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).requestFocus(new FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = context.bloc<UserBloc>();
    final User user = userBloc.user;
    final isUnset = context.bloc<OperationBloc>().isUnselected;
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(context, userBloc),
          _buildOperationListAction(context),
          Divider(),
          _buildMapAction(context),
          Divider(),
          _buildOperationHeader(isUnset, context),
          _buildUserProfilePageAction(context),
          _buildUserUnitPageAction(isUnset, context),
          _buildUserOperationPageAction(isUnset, context),
          _buildUserHistoryAction(isUnset, context),
          Divider(),
          _buildCommandHeader(isUnset, context),
//          _buildMissionsPageAction(isUnset, context),
          _buildUnitsPageAction(isUnset, context),
          _buildPersonnelsPageAction(isUnset, context),
          _buildDevicesPageAction(context),
          Divider(),
          _buildSettingsAction(context),
          _buildLogoutAction(user, context, userBloc),
        ],
      ),
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
        final answer = await prompt(
          context,
          'Bekreftelse',
          user.isTrusted
              ? 'Du logges nå ut. Vil du fortsette?'
              : 'Du er innlogget med en bruker som krever at pinkoden slettes ved utlogging. Vil du logge ut?',
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

  ListTile _buildUserHistoryAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.history),
      title: Text('Min historikk', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_HISTORY);
      },
    );
  }

  ListTile _buildUserProfilePageAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.account_box),
      title: Text('Min side', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_PROFILE);
      },
    );
  }

  ListTile _buildUserUnitPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.supervised_user_circle),
      title: Text('Min enhet', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_UNIT);
      },
    );
  }

  ListTile _buildUserOperationPageAction(bool isUnset, BuildContext context) {
    return ListTile(
      enabled: !isUnset,
      leading: const Icon(Icons.warning),
      title: Text('Min aksjon', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_OPERATION);
      },
    );
  }

  ListTile _buildDevicesPageAction(BuildContext context) {
    return ListTile(
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

  ListTile _buildOperationHeader(bool isUnset, BuildContext context) {
    final selected = context.bloc<OperationBloc>().selected;
    final labels = selected == null
        ? ['Ingen aksjon valgt']
        : [
            '${selected.name ?? translateOperationType(selected.type)}',
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
                leaveOperation();
              },
            ),
    );
  }

  ListTile _buildCommandHeader(bool isUnset, BuildContext context) {
    final labels = ['Aksjonsledelse'];

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

  ListTile _buildOperationListAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.format_list_bulleted),
      title: Text('Aksjoner', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, OperationsScreen.ROUTE);
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
