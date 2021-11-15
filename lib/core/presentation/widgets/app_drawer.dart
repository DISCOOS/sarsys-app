import 'package:SarSys/core/data/gravatar.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/operation/presentation/screens/command_screen.dart';
import 'package:SarSys/features/settings/presentation/screens/settings_screen.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/mapping/presentation/screens/map_screen.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/data/services/provider.dart';

import 'descriptions.dart';

class AppDrawer extends StatefulWidget {
  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  bool get isOffline => context.service<ConnectivityService>().isOffline;

  @override
  Widget build(BuildContext context) {
    final UserBloc userBloc = context.read<UserBloc>();
    final User user = userBloc.user;
    final isPrivate = !context.read<PersonnelBloc>().isUserMobilized;
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
          _buildOperationHeader(isPrivate, context),
          _buildUserProfilePageAction(context),
          _buildUserUnitPageAction(isPrivate, context),
          _buildUserOperationPageAction(isPrivate, context),
          _buildUserHistoryAction(isPrivate, context),
          Divider(),
          _buildCommandHeader(isPrivate, context),
//          _buildMissionsPageAction(isPrivate, context),
          _buildUnitsPageAction(isPrivate, context),
          _buildPersonnelsPageAction(isPrivate, context),
          _buildDevicesPageAction(context),
          Divider(),
          _buildSettingsAction(context),
          _buildLogoutAction(user, context, userBloc),
        ],
      ),
    );
  }

  Widget _buildLogoutAction(User user, BuildContext context, UserBloc userBloc) {
    return GestureDetector(
      child: ListTile(
        enabled: !isOffline,
        leading: const Icon(Icons.lock),
        title: Text('Logg av', style: TextStyle(fontSize: 14)),
        onTap: isOffline
            ? null
            : () async {
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
      ),
      onTap: isOffline
          ? () => alert(
                context,
                title: 'Ingen nettverk',
                content: Text('Du kan kun logge ut når du har nettverk'),
              )
          : null,
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

  ListTile _buildUserHistoryAction(bool isPrivate, BuildContext context) {
    return ListTile(
      enabled: !isPrivate,
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

  ListTile _buildUserUnitPageAction(bool isPrivate, BuildContext context) {
    return ListTile(
      enabled: !isPrivate,
      leading: const Icon(Icons.supervised_user_circle),
      title: Text('Min enhet', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_UNIT);
      },
    );
  }

  ListTile _buildUserOperationPageAction(bool isPrivate, BuildContext context) {
    return ListTile(
      enabled: !isPrivate,
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

  ListTile _buildPersonnelsPageAction(bool isPrivate, BuildContext context) {
    return ListTile(
      enabled: !isPrivate,
      leading: const Icon(Icons.person),
      title: Text('Mannskap', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_PERSONNEL_LIST);
      },
    );
  }

  ListTile _buildUnitsPageAction(bool isPrivate, BuildContext context) {
    return ListTile(
      enabled: !isPrivate,
      leading: const Icon(Icons.people),
      title: Text('Enheter', style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pushReplacementNamed(context, CommandScreen.ROUTE_UNIT_LIST);
      },
    );
  }

  ListTile _buildOperationHeader(bool isPrivate, BuildContext context) {
    final selected = context.read<OperationBloc>().selected;
    final labels = selected == null
        ? ['Ingen aksjon valgt']
        : [
            '${selected.name ?? translateOperationType(selected.type)}',
            '${selected.reference ?? ''}',
          ];

    return ListTile(
      enabled: !isPrivate,
      title: Wrap(
        children: labels
            .map((label) => Text(
                  label,
                  style: Theme.of(context).textTheme.bodyText2,
                ))
            .toList(),
      ),
      trailing: isPrivate
          ? null
          : ElevatedButton.icon(
              icon: Icon(toPersonnelStatusIcon(PersonnelStatus.leaving)),
              label: Text("SJEKK UT"),
              onPressed: () {
                Navigator.pop(context);
                leaveOperation();
              },
            ),
    );
  }

  ListTile _buildCommandHeader(bool isPrivate, BuildContext context) {
    final labels = ['Aksjonsledelse'];

    return ListTile(
      enabled: !isPrivate,
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
    final gravatar = Gravatar(user.email!);
    final url = gravatar.imageUrl(
      size: 100,
      defaultImage: GravatarImage.mp,
      fileExtension: true,
    );
    final avatar = Image.network(url);
    final roles = user.roles.toList();
    roles.sort((UserRole? e1, UserRole? e2) => e1!.index - e2!.index);
    return Stack(
      children: <Widget>[
        UserAccountsDrawerHeader(
          accountName: Text(
            "${user.fullName}",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          accountEmail: Text(
            user.email!,
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

  Widget _buildUserRoles(BuildContext context, List<UserRole?> roles) {
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
