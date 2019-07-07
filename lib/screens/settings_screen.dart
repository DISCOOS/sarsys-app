import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/services/talk_group_service.dart';
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
    bloc = BlocProvider.of<AppConfigBloc>(context).init(setState);
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
        child: AnimatedCrossFade(
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
                  child: StreamBuilder(
                    stream: bloc.state,
                    builder: (context, snapshot) {
                      return ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          ListTile(
                            title: Text(
                              "Generelt",
                              style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  "Tilhørighet",
                                ),
                                FutureBuilder(
                                  future: TalkGroupService().fetchCatalogs(),
                                  initialData: [],
                                  builder: (context, snapshot) {
                                    return snapshot.hasData
                                        ? DropdownButton<String>(
                                            items: _buildItems(snapshot.data),
                                            onChanged: (value) {
                                              bloc.update(affiliation: value);
                                            },
                                            value: bloc.config?.affiliation ?? Defaults.affiliation,
                                          )
                                        : [];
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(),
                          ListTile(
                            title: Text(
                              "Systeminnstillinger",
                              style: Theme.of(context).textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
                            ),
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
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildItems(List<dynamic> data) {
    data.sort();
    return data
        .map((affiliation) => DropdownMenuItem(
              value: "$affiliation",
              child: Text(
                "$affiliation",
              ),
            ))
        .toList();
  }
}
