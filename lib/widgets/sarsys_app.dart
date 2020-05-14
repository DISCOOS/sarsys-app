import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/app_state.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/map/models/map_widget_state_model.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/change_pin_screen.dart';
import 'package:SarSys/screens/device_screen.dart';
import 'package:SarSys/screens/first_setup_screen.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/screens/unlock_screen.dart';
import 'package:SarSys/screens/user_screen.dart';
import 'package:SarSys/services/navigation_service.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/widgets/network_sensitive.dart';
import 'package:SarSys/widgets/access_checker.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/core/extensions.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

class SarSysApp extends StatefulWidget {
  final PageStorageBucket bucket;
//  final BlocProviderController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  const SarSysApp({
    Key key,
    @required this.bucket,
//    @required this.controller,
    @required this.navigatorKey,
  }) : super(key: key);

  @override
  _SarSysAppState createState() => _SarSysAppState();
}

class _SarSysAppState extends State<SarSysApp> with WidgetsBindingObserver {
  final _checkerKey = UniqueKey();

  PermissionController controller;

  UserBloc get userBloc => context.bloc<UserBloc>();
  AppConfigBloc get configBloc => context.bloc<AppConfigBloc>();
  IncidentBloc get incidentBloc => context.bloc<IncidentBloc>();
  bool get onboarded => configBloc?.config?.onboarded ?? false;
  bool get firstSetup => configBloc?.config?.firstSetup ?? false;
  int get securityLockAfter => configBloc?.config?.securityLockAfter ?? Defaults.securityLockAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      writeAppState(widget.bucket);
    } else if (state == AppLifecycleState.resumed) {
      readAppState(widget.bucket);
      if (userBloc.isReady) {
        final heartbeat = userBloc.security.heartbeat;
        if (heartbeat == null || DateTime.now().difference(heartbeat).inMinutes > securityLockAfter) {
          await userBloc.lock();
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    readAppState(widget.bucket, context: context);
  }

  @override
  Widget build(BuildContext context) => _buildWithProviders(
      context: context,
      child: MaterialApp(
        navigatorKey: widget.navigatorKey,
        navigatorObservers: [RouteWriter.observer],
        debugShowCheckedModeBanner: false,
        title: 'SarSys',
        theme: ThemeData(
          primaryColor: Color(0xFF0d2149),
          buttonTheme: ButtonThemeData(
            height: 36.0,
            textTheme: ButtonTextTheme.primary,
          ),
        ),
        home: _toHome(),
        onGenerateRoute: (settings) => _toRoute(
          settings,
        ),
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en', 'US'), // English
          const Locale('nb', 'NO'), // Norwegian Bokmål
        ],
      ));

  Widget _buildWithProviders({
    @required BuildContext context,
    @required Widget child,
  }) =>
      PageStorage(
        bucket: widget.bucket,
        child: NetworkSensitive(
          child: Provider<PermissionController>(
            create: (BuildContext context) => controller,
            child: child,
          ),
        ),
      );

  Route _toRoute(RouteSettings settings) {
    WidgetBuilder builder;

    // Ensure logged in
    if (userBloc.isReady)
      builder = _toBuilder(
        settings,
        _toScreen(settings, false),
      );
    else if (!onboarded) {
      builder = _toUnchecked(OnboardingScreen());
    } else if (!firstSetup) {
      builder = _toUnchecked(FirstSetupScreen());
    } else if (!userBloc.isAuthenticated) {
      builder = _toUnchecked(LoginScreen());
    } else if (!userBloc.isSecured) {
      builder = _toUnchecked(ChangePinScreen());
    } else {
      builder = _toUnchecked(UnlockScreen());
    }

    writeAppState(widget.bucket);

    return MaterialPageRoute(
      builder: builder,
      settings: settings,
    );
  }

  WidgetBuilder _toBuilder(RouteSettings settings, Widget child) {
    WidgetBuilder builder;
    switch (settings.name) {
      case LoginScreen.ROUTE:
      case OnboardingScreen.ROUTE:
      case FirstSetupScreen.ROUTE:
        builder = _toUnchecked(child);
        break;
      default:
        builder = _toChecked(child);
        break;
    }
    return builder;
  }

  Widget _toScreen(RouteSettings settings, bool persisted) {
    Widget child;
    switch (settings.name) {
      case MapScreen.ROUTE:
        child = _toMapScreen(
          settings: settings,
          incident: context.bloc<IncidentBloc>().selected,
        );
        break;
      case LoginScreen.ROUTE:
        child = LoginScreen();
        break;
      case ChangePinScreen.ROUTE:
        child = ChangePinScreen(
          popOnClose: toArgument(
            settings,
            'popOnClose',
            defaultValue: false,
          ),
        );
        break;
      case UserScreen.ROUTE_INCIDENT:
        child = UserScreen(tabIndex: UserScreen.TAB_INCIDENT);
        break;
      case UnitScreen.ROUTE:
        child = _toUnitScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_UNIT_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_UNITS);
        break;
      case DeviceScreen.ROUTE:
        child = _toDeviceScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_MISSION_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_MISSIONS);
        break;
      case CommandScreen.ROUTE_DEVICE_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_DEVICES);
        break;
      case PersonnelScreen.ROUTE:
        child = _toPersonnelScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_PERSONNEL_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL);
        break;
      case UserScreen.ROUTE_STATUS:
        child = UserScreen(tabIndex: UserScreen.TAB_STATUS);
        break;
      case UserScreen.ROUTE_UNIT:
        child = UserScreen(tabIndex: UserScreen.TAB_UNIT);
        break;
      case UserScreen.ROUTE_HISTORY:
        child = UserScreen(tabIndex: UserScreen.TAB_HISTORY);
        break;
      case SettingsScreen.ROUTE:
        child = SettingsScreen();
        break;
      case OnboardingScreen.ROUTE:
        child = OnboardingScreen();
        break;
      case FirstSetupScreen.ROUTE:
        child = FirstSetupScreen();
        break;
      case IncidentsScreen.ROUTE:
      default:
        child = IncidentsScreen();
        break;
    }
    return child;
  }

  T toArgument<T>(RouteSettings settings, String path, {T defaultValue}) {
    if (settings.arguments is Map) {
      final arguments = settings.arguments as Map<String, dynamic>;
      return arguments.hasPath(path) ? arguments.elementAt(path) as T : defaultValue;
    }
    return defaultValue;
  }

  WidgetBuilder _toChecked(Widget child) => (context) => _buildWithProviders(
      context: context,
      child: AccessChecker(
        key: _checkerKey,
        child: child,
        configBloc: BlocProvider.of<AppConfigBloc>(context),
      ));

  WidgetBuilder _toUnchecked(Widget child) {
    return (context) => _buildWithProviders(context: context, child: child);
  }

  Widget _toMapScreen({RouteSettings settings, Incident incident}) {
    final arguments = settings?.arguments;
    if (arguments is Map) {
      return MapScreen(
        center: arguments["center"],
        incident: arguments["incident"] ?? incident,
        fitBounds: arguments["fitBounds"],
        fitBoundOptions: arguments["fitBoundOptions"],
      );
    }
    if (incident != null) {
      var model = readState<MapWidgetStateModel>(
        widget.navigatorKey.currentState.context,
        MapWidgetState.STATE,
      );
      if (model?.incident != incident.uuid) {
        final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
        final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
        final fitBounds = LatLngBounds(ipp, meetup);
        return MapScreen(
          incident: incident,
          fitBounds: fitBounds,
        );
      }
    }
    return MapScreen();
  }

  Widget _toUnitScreen(RouteSettings settings, bool persisted) {
    var unit;
    if (settings?.arguments is Unit) {
      unit = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      unit = units[route['data']];
    }
    return unit == null || persisted ? CommandScreen(tabIndex: CommandScreen.TAB_UNITS) : UnitScreen(unit: unit);
  }

  Map<String, Unit> get units => context.bloc<UnitBloc>().units;

  Widget _toPersonnelScreen(RouteSettings settings, bool persisted) {
    var personnel;
    if (settings?.arguments is Personnel) {
      personnel = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      personnel = personnels[route['data']];
    }
    return personnel == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL)
        : PersonnelScreen(personnel: personnel);
  }

  Map<String, Personnel> get personnels => context.bloc<PersonnelBloc>().personnels;

  Widget _toDeviceScreen(RouteSettings settings, bool persisted) {
    var device;
    if (settings?.arguments is Device) {
      device = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      device = devices[route['data']];
    }
    return device == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_DEVICES)
        : DeviceScreen(device: device);
  }

  Map<String, Device> get devices => context.bloc<DeviceBloc>().devices;

  Widget _toHome() {
    Widget child;
    if (configBloc.config.onboarded != true) {
      child = OnboardingScreen();
    } else if (configBloc.config.firstSetup != true) {
      child = FirstSetupScreen();
    } else if (userBloc.isReady) {
      var route = widget.bucket.readState(
        context,
        identifier: RouteWriter.STATE,
      );
      if (route is Map) {
        final _route = Map.from(route);
        final uuid = _route.elementAt('incidentId');
        if (uuid != null) {
          // On first load bloc's are not loaded yet
          incidentBloc.firstWhere((state) => state.isLoaded()).then((_) async {
            _route['incident'] = await selectIncident(uuid);
            NavigationService().pushReplacementNamed(
              _route[RouteWriter.FIELD_NAME],
              arguments: route,
            );
          });
        }
        bool isUnset = incidentBloc.isUnset;
        child = _toScreen(
          RouteSettings(
            name: isUnset ? 'incidents' : _route[RouteWriter.FIELD_NAME],
            arguments: isUnset ? null : route,
          ),
          true,
        );
      } else {
        child = _toMapScreen(
          incident: incidentBloc.selected,
        );
      }
      child = AccessChecker(
        key: _checkerKey,
        child: child,
        configBloc: configBloc,
      );
    } else if (!userBloc.isAuthenticated) {
      child = LoginScreen();
    } else if (!userBloc.isSecured) {
      child = ChangePinScreen();
    } else {
      child = UnlockScreen();
    }
    return _buildWithProviders(context: context, child: child);
  }
}
