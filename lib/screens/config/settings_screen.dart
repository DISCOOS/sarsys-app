import 'dart:io';
import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/app_state.dart';
import 'package:SarSys/screens/about_screen.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'incident_config_screen.dart';
import 'location_config_screen.dart';
import 'map_config_screen.dart';
import 'affiliation_config_screen.dart';
import 'permission_config_screen.dart';
import 'security_config_screen.dart';
import 'tetra_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const ROUTE = 'settings';
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc _configBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configBloc = BlocProvider.of<AppConfigBloc>(context);
  }

  @override //new
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return Scaffold(
          backgroundColor: Colors.white,
          key: _scaffoldKey,
          appBar: _buildAppBar(context),
          body: _buildBody(context, viewportConstraints),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
        title: Text("Innstillinger"),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ));
  }

  Widget _buildBody(BuildContext context, BoxConstraints viewportConstraints) {
    return RefreshIndicator(
      onRefresh: () async {
        _configBloc.load();
        setState(() {});
      },
      child: StreamBuilder(
        stream: _configBloc,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView(
                    shrinkWrap: true,
                    children: _buildSettings(context),
                  ),
                )
              : CircularProgressIndicator();
        },
      ),
    );
  }

  List<Widget> _buildSettings(BuildContext context) {
    return <Widget>[
      ListTile(
        title: Text(
          "Oppsett",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _buildGotoAffiliationConfig(),
      _buildGotoIncidentConfig(),
      _buildGotoMapConfig(),
      _buildGotoLocationConfig(),
      _buildGotoTetraConfig(),
      _buildGotoSecurityConfig(),
      _buildPermissionsConfig(),
      Divider(),
      ListTile(
        title: Text(
          "System",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      ListTile(
        title: Text(
          "Innstillinger for ${Platform.operatingSystem} app",
          style: Theme.of(context).textTheme.body1,
        ),
        trailing: Icon(Icons.open_in_new),
        onTap: () async {
          await PermissionHandler().openAppSettings();
        },
      ),
      _buildFactoryReset(),
      ListTile(
        title: Text(
          "Om SarSys",
          style: Theme.of(context).textTheme.body1,
        ),
        trailing: Icon(Icons.keyboard_arrow_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
            return AboutScreen();
          }));
        },
      ),
    ];
  }

  ListTile _buildGotoAffiliationConfig() {
    return ListTile(
      title: Text("Tilhørighet"),
      subtitle: Text('Endre innstillinger for tilhørighet'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return AffiliationConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoIncidentConfig() {
    return ListTile(
      title: Text("Aksjon"),
      subtitle: Text('Endre innstillinger for aksjon'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return IncidentConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoSecurityConfig() {
    return ListTile(
      title: Text("Sikkerhet"),
      subtitle: Text('Endre innstillinger for lokal sikkehet'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return SecurityConfigScreen();
        }));
      },
    );
  }

  ListTile _buildPermissionsConfig() {
    return ListTile(
      title: Text("Tillatelser"),
      subtitle: Text('Endre tillatelser'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return PermissionConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoMapConfig() {
    return ListTile(
      title: Text("Kart"),
      subtitle: Text('Endre innstillinger for kart og lagring'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return MapConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoLocationConfig() {
    return ListTile(
      title: Text("Posisjon og sporing"),
      subtitle: Text('Endre innstillinger posisjonering og sporing'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return LocationConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoTetraConfig() {
    return ListTile(
      title: Text("Nødnett"),
      subtitle: Text('Endre standardsverdier og oppførsel'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return TetraConfigScreen();
        }));
      },
    );
  }

  Widget _buildFactoryReset() {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text("Nullstill og konfigurerer på nytt")),
            Icon(
              Icons.keyboard_arrow_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
      onTap: () async {
        final reset = await prompt(
          context,
          "Bekreftelse",
          'Dette vil logge deg ut og gjenopprette fabrikkinnstillingene',
        );
        if (reset) {
          Navigator.pop(context);
          await clearAppStateAndData(context);
        }
      },
    );
  }
}
