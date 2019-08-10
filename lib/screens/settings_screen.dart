import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/screens/about_screen.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = BlocProvider.of<AppConfigBloc>(context);
  }

  @override //new
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return Scaffold(
          backgroundColor: Colors.white,
          key: _scaffoldKey,
          appBar: _buildAppBar(context),
          body: _buildBody(bloc, context, viewportConstraints),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
        title: Text("Preferanser"),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ));
  }

  Widget _buildBody(AppConfigBloc bloc, BuildContext context, BoxConstraints viewportConstraints) {
    return RefreshIndicator(
      onRefresh: () async {
        await bloc.fetch();
        setState(() {});
      },
      child: Container(
        color: Color.fromRGBO(168, 168, 168, 0.6),
        child: StreamBuilder(
          stream: bloc.state,
          builder: (context, snapshot) {
            return AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              crossFadeState: bloc.isReady ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Center(
                child: CircularProgressIndicator(),
              ),
              secondChild: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Container(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: ListView(
                        shrinkWrap: true,
                        children: _buildSettings(context, bloc),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSettings(BuildContext context, AppConfigBloc bloc) {
    return <Widget>[
      ListTile(
        title: Text(
          "Generelt",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _buildDistrictField(bloc),
      _buildDepartmentField(bloc),
      _buildTalkGroupsField(bloc),
      Divider(),
      ListTile(
        title: Text(
          "System",
          style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      GestureDetector(
        child: ListTile(
          title: Text(
            "Om SarSys",
            style: Theme.of(context).textTheme.body1,
          ),
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
            return AboutScreen();
          }));
        },
      ),
      GestureDetector(
        child: ListTile(
          title: Text(
            "Endre tilganger",
            style: Theme.of(context).textTheme.body1,
          ),
        ),
        onTap: () {
          PermissionHandler().openAppSettings();
        },
      )
    ];
  }

  Padding _buildDistrictField(AppConfigBloc bloc) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text("Distrikt")),
          FutureBuilder<Map<String, dynamic>>(
            future: AssetsService().fetchDistricts(),
            initialData: {},
            builder: (context, snapshot) {
              return Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  items: snapshot.hasData
                      ? snapshot.data.values
                          .map((name) => DropdownMenuItem<String>(
                                value: "$name",
                                child: Text("$name"),
                              ))
                          .toList()
                      : [],
                  onChanged: (value) {
                    bloc.update(district: value);
                  },
                  value: bloc.config?.district ?? Defaults.district,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Padding _buildDepartmentField(AppConfigBloc bloc) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text("Hjelpkorps")),
          FutureBuilder<Map<String, String>>(
            future: AssetsService().fetchDistricts(),
            initialData: {},
            builder: (context, snapshot) {
              return Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  items: snapshot.hasData
                      ? snapshot.data.values
                          .map((name) => DropdownMenuItem<String>(
                                value: "$name",
                                child: Text("$name"),
                              ))
                          .toList()
                      : [],
                  onChanged: (value) {
                    bloc.update(talkGroups: value);
                  },
                  value: bloc.config?.department ?? Defaults.department,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Padding _buildTalkGroupsField(AppConfigBloc bloc) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text("Nødnett")),
          FutureBuilder<List<String>>(
            future: AssetsService().fetchTalkGroupCatalogs(),
            initialData: [],
            builder: (context, snapshot) {
              return Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  items: snapshot.hasData
                      ? snapshot.data
                          .map((name) => DropdownMenuItem<String>(
                                value: "$name",
                                child: Text("$name"),
                              ))
                          .toList()
                      : [],
                  onChanged: (value) {
                    bloc.update(talkGroups: value);
                  },
                  value: bloc.config?.talkGroups ?? Defaults.talkGroups,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
