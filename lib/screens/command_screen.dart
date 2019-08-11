import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/editors/unit_editor.dart';
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
  final _unitsKey = GlobalKey<UnitsPageState>();
  final _devicesKey = GlobalKey<DevicesPageState>();

  var current;

  @override
  Widget build(BuildContext context) {
    final IncidentBloc incidentBloc = BlocProvider.of<IncidentBloc>(context);
    return StreamBuilder(
      stream: incidentBloc.changes,
      initialData: incidentBloc.current,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final incident = snapshot.data is Incident ? snapshot.data : null;
        final title = _toName(incident);
        final tabs = [
          IncidentPage(),
          UnitsPage(key: _unitsKey),
          DevicesPage(key: _devicesKey),
        ];
        return Scaffold(
          drawer: AppDrawer(),
          appBar: AppBar(
            actions: _buildActions(context, incident, incidentBloc),
            title: _buildTitle(title),
          ),
          body: tabs[current],
          resizeToAvoidBottomPadding: true,
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
          floatingActionButton: _buildFAB(context),
        );
      },
    );
  }

  Widget _buildTitle(title) => GestureDetector(
        child: Center(child: Text(title)),
        onTap: () {
          // TODO: Show general search
        },
      );

  _toName(Incident incident, {ifEmpty: "Hendelse"}) {
    switch (current) {
      case 0:
        String name = incident?.name;
        return name == null || name.isEmpty ? ifEmpty : name;
      case 1:
        return "Enheter";
      case 2:
        return "Terminaler";
    }
  }

  List<Widget> _buildActions(BuildContext context, incident, IncidentBloc incidentBloc) {
    switch (current) {
      case 0:
        return [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => IncidentEditor(incident: incident),
            ),
          )
        ];
      case 1:
        return [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              showSearch(context: context, delegate: UnitSearch());
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () async {
              _unitsKey.currentState.showFilterSheet(context);
            },
          )
        ];
      case 2:
        return [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              showSearch(context: context, delegate: DeviceSearch());
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () async {
              _devicesKey.currentState.showFilterSheet(context);
            },
          )
        ];
      default:
        return [Container()];
    }
  }

  StatelessWidget _buildFAB(BuildContext context) {
    return current == 1
        ? FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => UnitEditor(),
            ),
          )
        : Container();
  }

  @override
  void initState() {
    super.initState();
    super.initState();
    current = widget.tabIndex;
  }
}
