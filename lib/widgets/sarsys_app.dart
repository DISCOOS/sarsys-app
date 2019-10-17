import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/device_screen.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/screens/config/settings_screen.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/permission_checker.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

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
    return MaterialApp(
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
      builder: (context, child) {
        // will rebuild when blocs are rebuilt with Providers.rebuild
        return BlocProviderTree(
          blocProviders: widget.controller.all,
          child: child,
        );
      },
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
    );
  }

  Route _toRoute(RouteSettings settings) {
    WidgetBuilder builder;

    // Ensure logged in
    if (widget.controller.userProvider.bloc.isAuthenticated)
      builder = _toBuilder(settings, _toScreen(settings));
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

  Widget _toScreen(RouteSettings settings) {
    Widget child;
    switch (settings.name) {
      case 'login':
        child = LoginScreen();
        break;
      case 'incident':
        child = CommandScreen(tabIndex: 0);
        break;
      case 'unit':
        child = _toUnitScreen(settings);
        break;
      case 'units':
        child = CommandScreen(tabIndex: 1);
        break;
      case 'device':
        child = _toDeviceScreen(settings);
        break;
      case 'devices':
        child = CommandScreen(tabIndex: 2);
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

  Widget _toUnitScreen(RouteSettings settings) {
    var unit;
    if (settings?.arguments is Unit) {
      unit = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = settings?.arguments;
      unit = widget.controller.unitProvider.bloc.units[route['id']];
    }
    return unit == null ? CommandScreen(tabIndex: CommandScreen.UNITS) : UnitScreen(unit: unit);
  }

  Widget _toDeviceScreen(RouteSettings settings) {
    var device;
    if (settings?.arguments is Device) {
      device = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = settings?.arguments;
      device = widget.controller.deviceProvider.bloc.devices[route['id']];
    }
    return device == null ? CommandScreen(tabIndex: CommandScreen.DEVICES) : DeviceScreen(device: device);
  }

  Widget _toHome(BlocProviderController providers) {
    Widget child;
    if (providers.configProvider.bloc.config.onboarding) {
      child = OnboardingScreen();
    } else if (providers.userProvider.bloc.isAuthenticated) {
      final route = widget.bucket.readState(context, identifier: RouteWriter.NAME);
      if (route != null) {
        if (route['incident'] != null) {
          final id = route['incident'];
          providers.incidentProvider.bloc.select(id);
        }
        bool isUnset = providers.incidentProvider.bloc.isUnset;
        child = _toScreen(
          RouteSettings(
            name: isUnset ? 'incidents' : route['name'],
            isInitialRoute: true,
            arguments: isUnset ? null : route,
          ),
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
