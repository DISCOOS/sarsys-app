

import 'dart:io';
import 'dart:ui';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/presentation/screens/about_screen.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'debug_data_screen.dart';
import 'operation_config_screen.dart';
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

  late AppConfigBloc _configBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configBloc = context.read<AppConfigBloc>();
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
        stream: _configBloc.stream,
        initialData: _configBloc.state,
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
      _buildSection(context, "Oppsett"),
      _buildGotoAffiliationConfig(),
      _buildGotoOperationsConfig(),
      _buildGotoMapConfig(),
      _buildGotoLocationConfig(),
      _buildGotoTetraConfig(),
      _buildGotoSecurityConfig(),
      _buildPermissionsConfig(),
      Divider(),
      _buildSection(context, "System"),
      _buildAboutPage(context),
      _buildGotoDebugDataScreen(),
      _buildOsConfig(context),
      _buildFactoryReset(),
    ];
  }

  ListTile _buildSection(BuildContext context, String title) {
    return ListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  ListTile _buildOsConfig(BuildContext context) {
    return ListTile(
      title: Text(
        "Innstillinger for ${Platform.operatingSystem} app",
        style: Theme.of(context).textTheme.bodyText2,
      ),
      subtitle: Text("Endre innstillinger i operativsystemet"),
      trailing: Icon(Icons.open_in_new),
      onTap: () async {
        await openAppSettings();
      },
    );
  }

  ListTile _buildAboutPage(BuildContext context) {
    return ListTile(
      title: Text(
        "Om SarSys",
        style: Theme.of(context).textTheme.bodyText2,
      ),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return AboutScreen();
        }));
      },
    );
  }

  ListTile _buildGotoAffiliationConfig() {
    return ListTile(
      title: Text("Tilhørighet"),
      subtitle: Text('Endre innstillinger for tilhørighet'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return AffiliationConfigScreen(organisation: context.read<UserBloc>().user.org);
        }));
      },
    );
  }

  ListTile _buildGotoOperationsConfig() {
    return ListTile(
      title: Text("Aksjon"),
      subtitle: Text('Endre innstillinger for aksjon'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return OperationConfigScreen();
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
      subtitle: Text('Se tillatelser som er gitt'),
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

  ListTile _buildGotoDebugDataScreen() {
    return ListTile(
      title: Text('Lokale data'),
      subtitle: Text('Feilsøke data lagret lokalt'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return DebugDataScreen();
        }));
      },
    );
  }

  Widget _buildFactoryReset() {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
          await Provider.of<AppController>(context, listen: false).reset();
        }
      },
    );
  }
}
