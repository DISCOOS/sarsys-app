import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/pages/incident_page.dart';
import 'package:SarSys/pages/devices_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/usecase/device.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CommandScreen extends StatefulWidget {
  final int tabIndex;

  CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  @override
  _CommandScreenState createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final _unitsKey = GlobalKey<UnitsPageState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _devicesKey = GlobalKey<DevicesPageState>();

  int _current;
  UserBloc _userBloc;
  IncidentBloc _incidentBloc;

  @override
  void initState() {
    super.initState();
    _current = widget.tabIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override
  void didUpdateWidget(CommandScreen old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex) {
      _current = widget.tabIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _incidentBloc.changes(),
      initialData: _incidentBloc.current,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final incident = (snapshot.hasData ? _incidentBloc.current : null);
        final title = _toName(incident);
        final tabs = [
          IncidentPage(onMessage: _showMessage),
          UnitsPage(key: _unitsKey),
          DevicesPage(key: _devicesKey),
        ];
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            actions: _buildActions(incident),
            title: Text(title),
          ),
          body: tabs[_current],
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _current,
            elevation: 4.0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(title: Text("Hendelse"), icon: Icon(Icons.warning)),
              BottomNavigationBarItem(title: Text("Enheter"), icon: Icon(Icons.people)),
              BottomNavigationBarItem(title: Text("Apparater"), icon: Icon(MdiIcons.cellphoneBasic)),
            ],
            onTap: (index) => setState(() {
              _current = index;
            }),
          ),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  _toName(Incident incident, {ifEmpty: "Hendelse"}) {
    switch (_current) {
      case 0:
        String name = incident?.name;
        return name == null || name.isEmpty ? ifEmpty : name;
      case 1:
        return "Enheter";
      case 2:
        return "Apparater";
    }
  }

  List<Widget> _buildActions(incident) {
    switch (_current) {
      case 0:
        return [
          if (_userBloc?.user?.isCommander == true)
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async => await editIncident(context, incident),
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
              _unitsKey.currentState.showFilterSheet();
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
              _devicesKey.currentState.showFilterSheet();
            },
          )
        ];
      default:
        return [Container()];
    }
  }

  StatelessWidget _buildFAB() {
    if (_userBloc?.user?.isCommander == true) {
      switch (_current) {
        case 1:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createUnit(context),
          );
        case 2:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await attachDevice(context),
          );
      }
    }
    return Container();
  }

  void _showMessage(
    String message, {
    String action = "OK",
    VoidCallback onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildAction(action, () {
        if (onPressed != null) onPressed();
        _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  Widget _buildAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }
}
