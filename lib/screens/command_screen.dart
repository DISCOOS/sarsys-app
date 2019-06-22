import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/pages/incident_page.dart';
import 'package:SarSys/pages/devices_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/widgets/app_drawer.dart';
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
    return StreamBuilder(
      stream: bloc.updates,
      initialData: bloc.current,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final incident = snapshot.data is Incident ? snapshot.data : null;
        final title = incident?.reference ?? (incident?.name ?? "Hendelse");
        final tabs = [
          IncidentPage(incident),
          UnitsPage(),
          DevicesPage(),
        ];
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
            title: Tab(text: title),
          ),
          body: tabs[current],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: current,
            elevation: 4.0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(title: Text("Hendelse"), icon: Icon(Icons.warning)),
              BottomNavigationBarItem(title: Text("Enheter"), icon: Icon(Icons.people)),
              BottomNavigationBarItem(title: Text("Terminaler"), icon: Icon(Icons.device_unknown)),
            ],
            onTap: (index) => setState(() {
                  current = index;
                }),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    current = widget.tabIndex;
  }
}
