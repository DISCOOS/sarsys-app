import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'mock/incidents.dart';
import 'mock/users.dart';
import 'services/user_service.dart';
import 'screens/command_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  // TODO: Move url to (downloadable) config service/model
  final baseUrl = 'https://sporing.rodekors.no';
  final apiUrl = '$baseUrl/api';

  // Configure user service
  final UserService userService = kReleaseMode ? UserService('$baseUrl/auth/login') : UserServiceMock.buildAny();
  final UserBloc userBloc = UserBloc(userService);

  // Configure Incident service
  final IncidentService incidentService =
      kReleaseMode ? IncidentService(apiUrl) : IncidentServiceMock.build(userService, 2, "T123");
  final IncidentBloc incidentBloc = IncidentBloc(incidentService);

  final Widget homepage = await getHome(userBloc);

  runApp(BlocProviderTree(
    blocProviders: [
      BlocProvider<UserBloc>(bloc: userBloc),
      BlocProvider<IncidentBloc>(bloc: incidentBloc),
    ],
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SarSys',
        theme: new ThemeData(
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
          'plan': (BuildContext context) => CommandScreen(tabIndex: 1),
          'incidents': (BuildContext context) => IncidentsScreen(),
          'map': (BuildContext context) => MapScreen(),
        },
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'), // English
          const Locale('nb'), // English
        ]),
  ));
}

Future<Widget> getHome(UserBloc bloc) async {
  if (await bloc.init()) {
    return IncidentsScreen();
  } else {
    return LoginScreen();
  }
}
