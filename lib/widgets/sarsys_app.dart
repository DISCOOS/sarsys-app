import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/screens/settings_screen.dart';
import 'package:SarSys/widgets/permission_checker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

class SarSysApp extends StatefulWidget {
  final Key navigatorKey;
  final BlocProviderController controller;
  const SarSysApp({
    Key key,
    @required this.controller,
    @required this.navigatorKey,
  }) : super(key: key);

  @override
  _SarSysAppState createState() => _SarSysAppState();
}

class _SarSysAppState extends State<SarSysApp> {
  final _checkerKey = UniqueKey();

  StreamSubscription<UserState> _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription?.cancel();
    _subscription = widget.controller.userProvider.bloc.state.listen((state) {
      if (!(state.isAuthenticating() || state.isAuthenticated() || state.isAuthorized())) {
        final onboarding = widget.controller.configProvider?.bloc?.config?.onboarding;
        Navigator.of(context).pushReplacementNamed(onboarding ? "onboarding" : "login");
      }
    });
  }

  void dispose() {
    super.dispose();
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
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
    if (widget.controller.userProvider.bloc.isAuthenticated) {
      switch (settings.name) {
        case 'login':
          builder = _toUnchecked(LoginScreen());
          break;
        case 'incident':
          builder = _toChecked(CommandScreen(tabIndex: 0));
          break;
        case 'units':
          builder = _toChecked(CommandScreen(tabIndex: 1));
          break;
        case 'devices':
          builder = _toChecked(CommandScreen(tabIndex: 2));
          break;
        case 'incidents':
          builder = _toChecked(IncidentsScreen());
          break;
        case 'settings':
          builder = _toChecked(SettingsScreen());
          break;
        case 'map':
          builder = _toChecked(_toMapScreen(context));
          break;
        case 'onboarding':
          builder = _toUnchecked(OnboardingScreen());
          break;
      }
    } else {
      final onboarding = widget.controller.configProvider?.bloc?.config?.onboarding;
      builder = onboarding == true ? _toChecked(OnboardingScreen()) : _toUnchecked(LoginScreen());
    }

    return MaterialPageRoute(
      builder: builder,
      settings: settings,
    );
  }

  WidgetBuilder _toChecked(Widget child) {
    return (context) => PermissionChecker(
          key: _checkerKey,
          child: child,
        );
  }

  WidgetBuilder _toUnchecked(Widget child) {
    return (context) => child;
  }

  MapScreen _toMapScreen(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings?.arguments;
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

  Widget _toHome(BlocProviderController providers) {
    if (providers.configProvider.bloc.config.onboarding)
      return OnboardingScreen();
    else if (providers.userProvider.bloc.isAuthenticated)
      return PermissionChecker(
        key: _checkerKey,
        child: IncidentsScreen(),
      );
    else
      return LoginScreen();
  }
}
