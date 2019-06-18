import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/pages/incident_page.dart';
import 'package:SarSys/pages/terminals_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:SarSys/widgets/colored_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommandScreen extends StatefulWidget {
  final int tabIndex;

  CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  @override
  _CommandScreenState createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  var current;

  @override
  Widget build(BuildContext context) {
    final IncidentBloc bloc = BlocProvider.of<IncidentBloc>(context);
    return DefaultTabController(
      length: 3,
      initialIndex: current,
      child: StreamBuilder(
        stream: bloc.updates,
        initialData: bloc.current,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          var incident = snapshot.data is Incident ? snapshot.data : null;
          String title = incident?.reference ?? (incident?.name ?? "Hendelse");
          return Scaffold(
            drawer: AppDrawer(),
            appBar: AppBar(
              actions: <Widget>[
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () async {
                    var response = await showDialog(
                      context: context,
                      builder: (context) => IncidentEditor(incident: incident),
                    );
                    if (response != null) {
                      bloc.update(response);
                    }
                  },
                ),
              ],
              bottom: ColoredTabBar(
                Colors.white,
                TabBar(
                  labelColor: Colors.black,
                  tabs: [
                    Tab(text: "Hendelse", icon: Icon(Icons.warning)),
                    Tab(text: "Enheter", icon: Icon(Icons.people)),
                    Tab(text: "Terminaler", icon: Icon(Icons.device_unknown)),
                  ],
                  onTap: (index) => setState(() {
                        current = index;
                      }),
                ),
              ),
              title: Tab(text: title),
            ),
            floatingActionButton: current > 0
                ? FloatingActionButton(
                    onPressed: () {},
                    child: Icon(Icons.add),
                    elevation: 2.0,
                  )
                : Container(),
            body: TabBarView(
              children: [
                IncidentPage(incident),
                UnitsPage(),
                TerminalsPage(),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    current = widget.tabIndex;
  }
}
