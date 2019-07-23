import 'package:SarSys/providers.dart';
import 'package:SarSys/screens/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart';

import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/screens/map_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  final Client client = Client();
  final providers = Providers.build(client, mock: true, units: 15, devices: 30);
  final Widget homepage = await getHome(providers);

  // Initialize app-config
  providers.configProvider.bloc.fetch();

  runApp(BlocProviderTree(
    blocProviders: providers.all,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SarSys',
        theme: ThemeData(
          primaryColor: Colors.grey[850],
          buttonTheme: ButtonThemeData(
            height: 36.0,
            textTheme: ButtonTextTheme.primary,
          ),
          //accentColor: Colors.cyan[600],
        ),
        home: homepage,
        routes: <String, WidgetBuilder>{
          'login': (BuildContext context) => LoginScreen(),
          'incident': (BuildContext context) => CommandScreen(tabIndex: 0),
          'units': (BuildContext context) => CommandScreen(tabIndex: 1),
          'terminals': (BuildContext context) => CommandScreen(tabIndex: 2),
          'incidents': (BuildContext context) => IncidentsScreen(),
          'settings': (BuildContext context) => SettingsScreen(),
          'map': (BuildContext context) => MapScreen(center: ModalRoute.of(context).settings.arguments),
        },
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'), // English
          const Locale('nb'), // Norwegian
        ]),
  ));
}

Future<Widget> getHome(Providers providers) async {
  if (await providers.userProvider.bloc.init()) {
    return IncidentsScreen();
  } else {
    return LoginScreen();
  }
}
