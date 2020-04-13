import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/pages/incident_page.dart';
import 'package:SarSys/pages/user_history_page.dart';
import 'package:SarSys/pages/user_status_page.dart';
import 'package:SarSys/pages/user_unit_page.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserScreen extends StatefulWidget {
  UserScreen({Key key, @required this.tabIndex}) : super(key: key);

  static const TAB_INCIDENT = 0;
  static const TAB_UNIT = 1;
  static const TAB_STATUS = 2;
  static const TAB_HISTORY = 3;

  static const ROUTE_UNIT = 'user/unit';
  static const ROUTE_STATUS = 'user/status';
  static const ROUTE_INCIDENT = 'user/incident';
  static const ROUTE_HISTORY = 'user/history';

  static const ROUTES = [
    ROUTE_INCIDENT,
    ROUTE_UNIT,
    ROUTE_STATUS,
    ROUTE_HISTORY,
  ];

  final int tabIndex;

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends RouteWriter<UserScreen, int> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _unitKey = GlobalKey<UserUnitPageState>();
  final _statusKey = GlobalKey<UserStatusPageState>();
  final _historyKey = GlobalKey<UserHistoryPageState>();

  UserBloc _userBloc;
  IncidentBloc _incidentBloc;

  @override
  void initState() {
    super.initState();
    routeData = widget.tabIndex;
    routeName = UserScreen.ROUTES[routeData];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override
  void didUpdateWidget(UserScreen old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex) {
      writeRoute(
        data: widget.tabIndex,
        name: UserScreen.ROUTES[widget.tabIndex],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _incidentBloc.changes(),
        initialData: _incidentBloc.selected,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          final incident = (snapshot.hasData ? _incidentBloc.selected : null);
          final tabs = [
            IncidentPage(onMessage: _showMessage),
            UserUnitPage(key: _unitKey),
            UserStatusPage(key: _statusKey, onMessage: _showMessage),
            UserHistoryPage(key: _historyKey),
          ];
          return Scaffold(
            key: _scaffoldKey,
            drawer: AppDrawer(),
            appBar: AppBar(
              actions: _buildActions(),
              title: Text(_toTitle(incident)),
            ),
            body: tabs[routeData],
            resizeToAvoidBottomInset: false,
            bottomNavigationBar: Container(
              child: BottomNavigationBar(
                currentIndex: routeData,
                elevation: 16.0,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                type: BottomNavigationBarType.fixed,
                items: [
                  BottomNavigationBarItem(title: Text("Min aksjon"), icon: Icon(Icons.warning)),
                  BottomNavigationBarItem(title: Text("Min enhet"), icon: Icon(Icons.supervised_user_circle)),
                  BottomNavigationBarItem(title: Text("Min side"), icon: Icon(Icons.account_box)),
                  BottomNavigationBarItem(title: Text("Min historikk"), icon: Icon(Icons.history)),
                ],
                onTap: (index) => setState(() {
                  writeRoute(
                    data: index,
                    name: UserScreen.ROUTES[index],
                  );
                }),
              ),
            ),
          );
        });
  }

  _toTitle(Incident incident, {ifEmpty: "Aksjon"}) {
    switch (routeData) {
      case UserScreen.TAB_INCIDENT:
        String name = incident?.name ?? "Aksjon";
        return name == null || name.isEmpty ? ifEmpty : name;
      case UserScreen.TAB_STATUS:
        return "Min side";
      case UserScreen.TAB_UNIT:
        return "Min enhet";
      case UserScreen.TAB_HISTORY:
        return "Min historikk";
    }
  }

  List<Widget> _buildActions() {
    switch (routeData) {
      case UserScreen.TAB_INCIDENT:
        return [
          if (_userBloc?.user?.isCommander == true)
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () async => await editIncident(_incidentBloc.selected),
            )
        ];
      case UserScreen.TAB_STATUS:
        return [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          )
        ];
      case UserScreen.TAB_UNIT:
        return [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          )
        ];
      case UserScreen.TAB_HISTORY:
        return [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          )
        ];
      default:
        return [Container()];
    }
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
      action: _buildSnackBarAction(action, () {
        if (onPressed != null) onPressed();
        _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  Widget _buildSnackBarAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }
}
