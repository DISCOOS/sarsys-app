import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/screens/about_screen.dart';
import 'package:SarSys/screens/config/map_config_screen.dart';
import 'package:SarSys/screens/config/tetra_config_screen.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/widgets/affilliation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'incident_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _affiliationKey = GlobalKey<AffiliationFormState>();

  AppConfigBloc _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = BlocProvider.of<AppConfigBloc>(context);
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
        _bloc.fetch();
        setState(() {});
      },
      child: StreamBuilder(
        stream: _bloc.state,
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              shrinkWrap: true,
              children: _buildSettings(context),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSettings(BuildContext context) {
    return <Widget>[
      ListTile(
        title: Text(
          "Tilhørighet",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: AffiliationForm(
          key: _affiliationKey,
          initialValue: _ensureAffiliation(),
          onChanged: (affiliation) => _bloc.update(
            division: affiliation.division,
            department: affiliation.department,
          ),
        ),
      ),
      ListTile(
        title: Text(
          "Oppsett",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _buildGotoIncidentConfig(),
      _buildGotoMapConfig(),
      _buildGotoTetraConfig(),
      Divider(),
      ListTile(
        title: Text(
          "System",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _buildOnboardingField(),
      ListTile(
        title: Text(
          "Endre tilganger for app",
          style: Theme.of(context).textTheme.body1,
        ),
        trailing: Icon(Icons.open_in_new),
        onTap: () async {
          await PermissionHandler().openAppSettings();
        },
      ),
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

  Affiliation _ensureAffiliation() => Affiliation(
        organization: Defaults.organization,
        division: _bloc.config.division ?? Defaults.division,
        department: _bloc.config?.department ?? Defaults.department,
      );

  ListTile _buildGotoIncidentConfig() {
    return ListTile(
      title: Text("Hendelse"),
      subtitle: Text('Endre innstillinger for hendelse'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return IncidentConfigScreen();
        }));
      },
    );
  }

  ListTile _buildGotoMapConfig() {
    return ListTile(
      title: Text("Kart"),
      subtitle: Text('Endre innstillinger for sporing og lagring'),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
          return MapConfigScreen();
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

  Padding _buildOnboardingField() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text("Vis oppstartsveiviser")),
          Switch(
            value: _bloc.config.onboarding,
            onChanged: (value) => _bloc.update(onboarding: value),
          ),
        ],
      ),
    );
  }
}
