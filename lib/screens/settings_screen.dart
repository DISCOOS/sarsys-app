import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/screens/about_screen.dart';
import 'package:SarSys/screens/map_config_screen.dart';
import 'package:SarSys/screens/tetra_config_screen.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc _bloc;

  Future<Organization> _organization;
  ValueNotifier<Division> _division = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _organization = AssetsService().fetchOrganization(Defaults.orgId)
      ..then((org) => _division.value = org.divisions[_bloc?.config?.division]);
  }

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
          return toRefreshable(
            viewportConstraints,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                shrinkWrap: true,
                children: _buildSettings(context),
              ),
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
      _buildDivisionField(),
      _buildDepartmentField(),
      ListTile(
        title: Text(
          "Oppsett",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
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

  Padding _buildDivisionField() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(flex: 2, child: Text("Distrikt")),
          FutureBuilder<Organization>(
            future: _organization,
            builder: (context, snapshot) {
              return Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  disabledHint: Text("Laster..."),
                  items: snapshot.hasData
                      ? sortMapValues<String, Division, String>(snapshot.data.divisions, (division) => division.name)
                          .entries
                          .map((division) => DropdownMenuItem<String>(
                                value: "${division.key}",
                                child: Text("${division.value.name}"),
                              ))
                          .toList()
                      : null,
                  onChanged: (value) {
                    _division.value = snapshot.data.divisions[value];
                    _bloc.update(district: value);
                  },
                  value: _bloc.config?.division ?? Defaults.division,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Padding _buildDepartmentField() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(flex: 2, child: Text("Hjelpkorps")),
          ValueListenableBuilder<Division>(
            valueListenable: _division,
            builder: (context, division, _) {
              return Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  disabledHint: Text("Velg distrikt"),
                  items: _ensureDepartments(division),
                  onChanged: (value) => _bloc.update(department: value),
                  value: _ensureDepartment(division),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _ensureDepartments(Division division) {
    return division != null
        ? sortMapValues<String, String, String>(division.departments)
            .entries
            .map((department) => DropdownMenuItem<String>(
                  value: "${department.key}",
                  child: Text("${department.value}"),
                ))
            .toList()
        : null;
  }

  String _ensureDepartment(Division division) {
    final value = division?.departments?.containsKey(_bloc.config?.department ?? Defaults.department) == true
        ? _bloc.config?.department ?? Defaults.department
        : division?.departments?.keys?.first;
    if (value != null && _bloc.config?.department != value) {
      _bloc.update(department: value);
    }
    return value;
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
