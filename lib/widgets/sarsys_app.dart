import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/device_screen.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/network_sensitive.dart';
import 'package:SarSys/widgets/permission_checker.dart';
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      writeAppState(widget.bucket);
    } else if (state == AppLifecycleState.resumed) {
      readAppState(widget.bucket);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkSensitive(
      child: Provider<Client>(
        builder: (BuildContext context) => widget.controller.client,
        child: BlocProviderTree(
          blocProviders: widget.controller.all,
          child: MaterialApp(
            navigatorKey: widget.navigatorKey,
            navigatorObservers: [RouteWriter.observer],
            debugShowCheckedModeBanner: false,
            title: 'SarSys',
            theme: ThemeData(
              primaryColor: Colors.grey[850],
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
          ),
        ),
      ),
    );
  }

  Route _toRoute(RouteSettings settings) {
    WidgetBuilder builder;

    // Ensure logged in
    if (widget.controller.userProvider.bloc.isAuthenticated)
      builder = _toBuilder(settings, _toScreen(settings, false));
    else {
      final onboarding = widget.controller.configProvider?.bloc?.config?.onboarding;
      builder = _toUnchecked(onboarding == true ? OnboardingScreen() : LoginScreen());
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
      case 'login':
        child = LoginScreen();
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
      case 'map':
        child = _toMapScreen(settings);
        break;
      case 'onboarding':
        child = OnboardingScreen();
        break;
      case 'incident/list':
      default:
        child = IncidentsScreen();
        break;
    }
    return child;
  }

  WidgetBuilder _toChecked(Widget child) {
    return (context) => PageStorage(
          bucket: widget.bucket,
          child: PermissionChecker(
            key: _checkerKey,
            child: child,
          ),
        );
  }

  WidgetBuilder _toUnchecked(Widget child) {
    return (context) => PageStorage(
          bucket: widget.bucket,
          child: child,
        );
  }

  Widget _toMapScreen(RouteSettings settings) {
    final arguments = settings?.arguments;
    if (arguments is Map) {
      return MapScreen(
        center: arguments["center"],
        incident: arguments["incident"],
        fitBounds: arguments["fitBounds"],
        fitBoundOptions: arguments["fitBoundOptions"],
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
      unit = widget.controller.unitProvider.bloc.units[route['id']];
    }
    return unit == null || persisted ? CommandScreen(tabIndex: CommandScreen.UNITS) : UnitScreen(unit: unit);
  }

  Widget _toPersonnelScreen(RouteSettings settings, bool persisted) {
    var personnel;
    if (settings?.arguments is Personnel) {
      personnel = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      personnel = widget.controller.personnelProvider.bloc.personnel[route['id']];
    }
    return personnel == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.PERSONNEL)
        : PersonnelScreen(personnel: personnel);
  }

  Widget _toDeviceScreen(RouteSettings settings, bool persisted) {
    var device;
    if (settings?.arguments is Device) {
      device = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      device = widget.controller.deviceProvider.bloc.devices[route['id']];
    }
    return device == null || persisted ? CommandScreen(tabIndex: CommandScreen.DEVICES) : DeviceScreen(device: device);
  }

  Widget _toHome(BlocProviderController providers) {
    Widget child;
    if (providers.configProvider.bloc.config.onboarding) {
      child = OnboardingScreen();
    } else if (providers.userProvider.bloc.isAuthenticated) {
      var route = widget.bucket.readState(context, identifier: RouteWriter.NAME);
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
      } else if (providers.incidentProvider.bloc.isUnset) {
        child = IncidentsScreen();
      } else {
        final incident = providers.incidentProvider.bloc.current;
        final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
        final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
        final fitBounds = LatLngBounds(ipp, meetup);
        child = MapScreen(
          incident: incident,
          fitBounds: fitBounds,
        );
      }
      child = PermissionChecker(
        key: _checkerKey,
        child: child,
      );
    } else {
      child = LoginScreen();
    }
    return PageStorage(
      bucket: widget.bucket,
      child: child,
    );
  }
}
