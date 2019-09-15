import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/core/bloc_provider_controller.dart';
import 'package:SarSys/screens/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

class SarSysApp extends StatelessWidget {
  final Key navigatorKey;
  final BlocProviderController controller;
  const SarSysApp({
    Key key,
    @required this.controller,
    @required this.navigatorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SarSys',
      theme: ThemeData(
        primaryColor: Colors.grey[850],
        buttonTheme: ButtonThemeData(
          height: 36.0,
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      home: _toHome(controller),
      builder: (context, child) {
        // will rebuild when blocs are rebuilt with Providers.rebuild
        return BlocProviderTree(
          blocProviders: controller.all,
          child: child,
        );
      },
      onGenerateRoute: (settings) => _toRoute(controller, settings),
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

  Route _toRoute(BlocProviderController controller, RouteSettings settings) {
    WidgetBuilder builder;

    // Ensure logged in
    if (controller.userProvider.bloc.isAuthenticated) {
      switch (settings.name) {
        case 'login':
          builder = (context) => LoginScreen();
          break;
        case 'incident':
          builder = (context) => CommandScreen(tabIndex: 0);
          break;
        case 'units':
          builder = (context) => CommandScreen(tabIndex: 1);
          break;
        case 'devices':
          builder = (context) => CommandScreen(tabIndex: 2);
          break;
        case 'incidents':
          builder = (context) => IncidentsScreen();
          break;
        case 'settings':
          builder = (context) => SettingsScreen();
          break;
        case 'map':
          builder = (context) => _toMapScreen(context);
          break;
        case 'onboarding':
          builder = (context) => OnboardingScreen();
          break;
      }
    } else {
      builder = (context) {
        final onboarding = BlocProvider.of<AppConfigBloc>(context)?.config?.onboarding;
        return onboarding == true ? OnboardingScreen() : LoginScreen();
      };
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  MapScreen _toMapScreen(BuildContext context) {
    final arguments = ModalRoute.of(context).settings.arguments;
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
      return IncidentsScreen();
    else
      return LoginScreen();
  }
}
