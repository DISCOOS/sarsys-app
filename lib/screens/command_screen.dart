import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/device/presentation/pages/devices_page.dart';
import 'package:SarSys/pages/missions_page.dart';
import 'package:SarSys/features/personnel/presentation/pages/personnel_page.dart';
import 'package:SarSys/features/unit/presentation/pages/units_page.dart';
import 'package:SarSys/features/device/domain/usecases/device_use_cases.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CommandScreen extends StatefulWidget {
  static const TAB_UNITS = 0;
  static const TAB_PERSONNEL = 1;
  static const TAB_DEVICES = 2;
  static const TAB_MISSIONS = 3;

  static const ROUTE_UNIT_LIST = 'unit/list';
  static const ROUTE_DEVICE_LIST = 'device/list';
  static const ROUTE_PERSONNEL_LIST = 'personnel/list';
  static const ROUTE_MISSION_LIST = 'mission/list';

  static const ROUTES = [
    ROUTE_UNIT_LIST,
    ROUTE_PERSONNEL_LIST,
    ROUTE_DEVICE_LIST,
    ROUTE_MISSION_LIST,
  ];

  final int tabIndex;

  CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  @override
  _CommandScreenState createState() => _CommandScreenState();
}

class _CommandScreenState extends RouteWriter<CommandScreen, int> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _missionsKey = GlobalKey<MissionsPageState>();
  final _unitsKey = GlobalKey<UnitsPageState>();
  final _personnelKey = GlobalKey<PersonnelPageState>();
  final _devicesKey = GlobalKey<DevicesPageState>();

  @override
  void initState() {
    super.initState();
    routeData = widget.tabIndex;
    routeName = CommandScreen.ROUTES[routeData];
  }

  @override
  void didUpdateWidget(CommandScreen old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex) {
      writeRoute(
        data: widget.tabIndex,
        name: CommandScreen.ROUTES[widget.tabIndex],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: context.bloc<OperationBloc>().onChanged(),
      initialData: context.bloc<OperationBloc>().selected,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final operation = (snapshot.hasData ? context.bloc<OperationBloc>().selected : null);
        final title = _toTitle(operation);
        final tabs = [
          UnitsPage(key: _unitsKey),
          PersonnelPage(key: _personnelKey),
          DevicesPage(key: _devicesKey),
          MissionsPage(key: _missionsKey),
        ];
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            actions: _buildActions(operation),
            title: Text(title),
          ),
          body: tabs[routeData],
          bottomNavigationBar: BottomAppBar(
            shape: isCommander(context) ? CircularNotchedRectangle() : null,
            notchMargin: 8.0,
            elevation: 16.0,
            child: FractionallySizedBox(
              widthFactor: isCommander(context) ? 0.80 : 1.0,
              alignment: Alignment.bottomLeft,
              child: BottomNavigationBar(
                currentIndex: routeData,
                elevation: 0.0,
                backgroundColor: Colors.transparent,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                items: [
//                  BottomNavigationBarItem(title: Text("Oppdrag"), icon: Icon(Icons.assessment)),
                  BottomNavigationBarItem(title: Text("Enheter"), icon: Icon(Icons.people)),
                  BottomNavigationBarItem(title: Text("Mannskap"), icon: Icon(Icons.person)),
                  BottomNavigationBarItem(title: Text("Apparater"), icon: Icon(MdiIcons.cellphoneBasic)),
                ],
                onTap: (index) => setState(() {
                  writeRoute(
                    data: index,
                    name: CommandScreen.ROUTES[index],
                  );
                }),
              ),
            ),
          ),
          floatingActionButton: _buildFAB(),
          floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        );
      },
    );
  }

  bool isCommander(BuildContext context) => context.bloc<UserBloc>()?.user?.isCommander == true;

  _toTitle(Operation operation, {ifEmpty: "Aksjon"}) {
    switch (routeData) {
      case CommandScreen.TAB_MISSIONS:
        return "Oppdrag";
      case CommandScreen.TAB_UNITS:
        return "Enheter";
      case CommandScreen.TAB_PERSONNEL:
        return "Mannskap";
      case CommandScreen.TAB_DEVICES:
        return "Apparater";
    }
  }

  List<Widget> _buildActions(operation) {
    switch (routeData) {
      case CommandScreen.TAB_MISSIONS:
        return _buildListActions<Unit>(
          delegate: MissionSearch(),
          onPressed: () async {
            _missionsKey.currentState.showFilterSheet();
          },
        );
      case CommandScreen.TAB_UNITS:
        return _buildListActions<Unit>(
          delegate: UnitSearch(),
          onPressed: () async {
            _unitsKey.currentState.showFilterSheet();
          },
        );
      case CommandScreen.TAB_PERSONNEL:
        return _buildListActions<Personnel>(
          delegate: PersonnelSearch(),
          onPressed: () async {
            _personnelKey.currentState.showFilterSheet();
          },
        );
      case CommandScreen.TAB_DEVICES:
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
    if (isCommander(context)) {
      switch (routeData) {
        case CommandScreen.TAB_MISSIONS:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createUnit(),
          );
        case CommandScreen.TAB_UNITS:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createUnit(),
          );
        case CommandScreen.TAB_PERSONNEL:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createPersonnel(),
          );
        case CommandScreen.TAB_DEVICES:
          return FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async => await createDevice(),
          );
      }
    }
    return Container();
  }
}
