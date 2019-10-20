import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/incident_page.dart';
import 'package:SarSys/pages/devices_page.dart';
import 'package:SarSys/pages/personnel_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/usecase/device.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CommandScreen extends StatefulWidget {
  static const INCIDENT = 0;
  static const UNITS = 1;
  static const PERSONNEL = 2;
  static const DEVICES = 3;
  static const ROUTES = ["incident", "units", "devices", "personnel"];

  final int tabIndex;

  CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  @override
  _CommandScreenState createState() => _CommandScreenState();
}

class _CommandScreenState extends RouteWriter<CommandScreen, int> {
  final _unitsKey = GlobalKey<UnitsPageState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _personnelKey = GlobalKey<PersonnelPageState>();
  final _devicesKey = GlobalKey<DevicesPageState>();

  UserBloc _userBloc;
  IncidentBloc _incidentBloc;

  @override
  void initState() {
    super.initState();
    id = widget.tabIndex;
    name = CommandScreen.ROUTES[id];
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
      write(widget.tabIndex, name: CommandScreen.ROUTES[widget.tabIndex]);
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
          PersonnelPage(key: _personnelKey),
          DevicesPage(key: _devicesKey),
        ];
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            actions: _buildActions(incident),
            title: Text(title),
          ),
          body: tabs[id],
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: id,
            elevation: 4.0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(title: Text("Hendelse"), icon: Icon(Icons.warning)),
              BottomNavigationBarItem(title: Text("Enheter"), icon: Icon(Icons.people)),
              BottomNavigationBarItem(title: Text("Mannskap"), icon: Icon(Icons.person)),
              BottomNavigationBarItem(title: Text("Apparater"), icon: Icon(MdiIcons.cellphoneBasic)),
            ],
            onTap: (index) => setState(() {
              write(index, name: CommandScreen.ROUTES[index]);
            }),
          ),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  _toName(Incident incident, {ifEmpty: "Hendelse"}) {
    switch (id) {
      case CommandScreen.INCIDENT:
        String name = incident?.name ?? "Hendelse";
        return name == null || name.isEmpty ? ifEmpty : name;
      case CommandScreen.UNITS:
        return "Enheter";
      case CommandScreen.PERSONNEL:
        return "Mannskap";
      case CommandScreen.DEVICES:
        return "Apparater";
    }
  }

  List<Widget> _buildActions(incident) {
    switch (id) {
      case CommandScreen.INCIDENT:
        return [
          if (_userBloc?.user?.isCommander == true)
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async => await editIncident(context, incident),
            )
        ];
      case CommandScreen.UNITS:
        return _buildListActions<Unit>(
          delegate: UnitSearch(),
          onPressed: () async {
            _unitsKey.currentState.showFilterSheet();
          },
        );
      case CommandScreen.PERSONNEL:
        return _buildListActions<Personnel>(
          delegate: PersonnelSearch(),
          onPressed: () async {
            _personnelKey.currentState.showFilterSheet();
          },
        );
      case CommandScreen.DEVICES:
        return _buildListActions<Device>(
          delegate: DeviceSearch(),
          onPressed: () async {
            _devicesKey.currentState.showFilterSheet();
          },
        );
      default:
        return [Container()];
    }
  }

  List<Widget> _buildListActions<T>({SearchDelegate<T> delegate, VoidCallback onPressed}) {
    return [
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () async {
          showSearch<T>(context: context, delegate: delegate);
        },
      ),
      IconButton(
        icon: Icon(Icons.filter_list),
        onPressed: onPressed,
      )
    ];
  }

  StatelessWidget _buildFAB() {
    if (_userBloc?.user?.isCommander == true) {
      switch (id) {
        case CommandScreen.UNITS:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createUnit(context),
          );
        case CommandScreen.PERSONNEL:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createPersonnel(context),
          );
        case CommandScreen.DEVICES:
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
