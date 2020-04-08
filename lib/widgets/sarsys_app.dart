import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/device_screen.dart';
import 'package:SarSys/screens/first_setup_screen.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/network_sensitive.dart';
import 'package:SarSys/widgets/access_checker.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

class SarSysApp extends StatefulWidget {
  final Key navigatorKey;
  final PageStorageBucket bucket;
  final BlocProviderController controller;
  const SarSysApp({
    Key key,
    @required this.bucket,
    @required this.controller,
    @required this.navigatorKey,
  }) : super(key: key);

  @override
  _SarSysAppState createState() => _SarSysAppState();
}

class _SarSysAppState extends State<SarSysApp> with WidgetsBindingObserver {
  final _checkerKey = UniqueKey();

  PermissionController controller;

  UserBloc get userBloc => widget.controller.userProvider.bloc;
  AppConfigBloc get configBloc => widget.controller.configProvider?.bloc;
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
    if (state == AppLifecycleState.paused) {
      writeAppState(widget.bucket);
      // Lock access to app on pause only (inactive state should NOT lock the app for usability reasons)
      if (userBloc.isReady) {
        await userBloc.secure(
          userBloc.security.pin,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (userBloc.isReady) {
        final heartbeat = userBloc.security.heartbeat;
        // If paused more than 30 seconds - lock access
        if (heartbeat == null || DateTime.now().difference(heartbeat).inMinutes > securityLockAfter) {
          await userBloc.lock();
        } else {
          await userBloc.secure(
            userBloc.security.pin,
          );
        }
      }
      readAppState(widget.bucket);
    }
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
        home: _toHome(widget.controller),
        onGenerateRoute: (settings) => _toRoute(settings),
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
          child: Provider<Client>(
            create: (BuildContext context) => widget.controller.client,
            child: Provider<PermissionController>(
              create: (BuildContext context) => controller,
              child: Provider<BlocProviderController>(
                create: (BuildContext context) => widget.controller,
                child: BlocProviderTree(
                  blocProviders: widget.controller.all,
                  child: child,
                ),
              ),
            ),
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
    else {
      builder = _toUnchecked(
        onboarded == false ? OnboardingScreen() : (firstSetup == false ? FirstSetupScreen() : LoginScreen()),
      );
    }

    return MaterialPageRoute(
      builder: builder,
      settings: settings,
    );
  }

  WidgetBuilder _toBuilder(RouteSettings settings, Widget child) {
    WidgetBuilder builder;
    switch (settings.name) {
      case 'login':
      case 'onboarding':
      case 'first_setup':
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
      case 'map':
        child = _toMapScreen(
          settings: settings,
          incident: widget.controller.incidentProvider.bloc.current,
        );
        break;
      case 'login':
        child = LoginScreen();
        break;
      case 'change/pin':
        child = LoginScreen(type: LoginType.changePin);
        break;
      case 'switch/user':
        child = LoginScreen(type: LoginType.switchUser);
        break;
      case 'incident':
        child = CommandScreen(tabIndex: CommandScreen.INCIDENT);
        break;
      case 'unit':
        child = _toUnitScreen(settings, persisted);
        break;
      case 'unit/list':
        child = CommandScreen(tabIndex: CommandScreen.UNITS);
        break;
      case 'personnel':
        child = _toPersonnelScreen(settings, persisted);
        break;
      case 'personnel/list':
        child = CommandScreen(tabIndex: CommandScreen.PERSONNEL);
        break;
      case 'device':
        child = _toDeviceScreen(settings, persisted);
        break;
      case 'device/list':
        child = CommandScreen(tabIndex: CommandScreen.DEVICES);
        break;
      case 'settings':
        child = SettingsScreen();
        break;
      case 'onboarding':
        child = OnboardingScreen();
        break;
      case 'first_setup':
        child = FirstSetupScreen();
        break;
      case 'incident/list':
      default:
        child = IncidentsScreen();
        break;
    }
    return child;
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
      final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
      final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
      final fitBounds = LatLngBounds(ipp, meetup);
      return MapScreen(
        incident: incident,
        fitBounds: fitBounds,
      );
    }
    return MapScreen();
  }

  Widget _toUnitScreen(RouteSettings settings, bool persisted) {
    var unit;
    if (settings?.arguments is Unit) {
      unit = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      unit = units[route['id']];
    }
    return unit == null || persisted ? CommandScreen(tabIndex: CommandScreen.UNITS) : UnitScreen(unit: unit);
  }

  Map<String, Unit> get units => widget.controller.unitProvider.bloc.units;

  Widget _toPersonnelScreen(RouteSettings settings, bool persisted) {
    var personnel;
    if (settings?.arguments is Personnel) {
      personnel = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      personnel = personnels[route['id']];
    }
    return personnel == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.PERSONNEL)
        : PersonnelScreen(personnel: personnel);
  }

  Map<String, Personnel> get personnels => widget.controller.personnelProvider.bloc.personnel;

  Widget _toDeviceScreen(RouteSettings settings, bool persisted) {
    var device;
    if (settings?.arguments is Device) {
      device = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      device = devices[route['id']];
    }
    return device == null || persisted ? CommandScreen(tabIndex: CommandScreen.DEVICES) : DeviceScreen(device: device);
  }

  Map<String, Device> get devices => widget.controller.deviceProvider.bloc.devices;

  Widget _toHome(BlocProviderController providers) {
    Widget child;
    if (providers.configProvider.bloc.config.onboarded != true) {
      child = OnboardingScreen();
    } else if (providers.configProvider.bloc.config.firstSetup != true) {
      child = FirstSetupScreen();
    } else if (providers.userProvider.bloc.isReady) {
      var route = widget.bucket.readState(
        context,
        identifier: RouteWriter.NAME,
      );
      if (route != null) {
        if (route['incident'] != null) {
          final id = route['incident'];
          providers.incidentProvider.bloc.select(id);
          route = Map.from(route);
          route['incident'] = providers.incidentProvider.bloc.current;
        }
        bool isUnset = providers.incidentProvider.bloc.isUnset;
        child = _toScreen(
          RouteSettings(
            name: isUnset ? 'incidents' : route['name'],
            isInitialRoute: true,
            arguments: isUnset ? null : route,
          ),
          true,
        );
      } else {
        child = _toMapScreen(
          incident: providers.incidentProvider.bloc.current,
        );
      }
      child = AccessChecker(
        key: _checkerKey,
        child: child,
        configBloc: providers.configProvider.bloc,
      );
    } else {
      child = LoginScreen();
    }
    return _buildWithProviders(context: context, child: child);
  }
}
