import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'mock/incidents.dart';
import 'services/UserService.dart';
import 'screens/CommandScreen.dart';
import 'screens/IncidentsScreen.dart';
import 'screens/LoginScreen.dart';
import 'screens/MapScreen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  final baseUrl = 'https://sporing.rodekors.no';
  final apiUrl = '$baseUrl/api/';

  final IncidentService service = kReleaseMode ? IncidentService(apiUrl) : IncidentServiceMock.build(2);
  final IncidentBloc incidentBloc = IncidentBloc(service);

  final Widget homepage = await getHome(false);

  runApp(BlocProvider(
    bloc: incidentBloc,
    child: MaterialApp(
      //debugShowCheckedModeBanner: false,
      title: 'SarSys',
      theme: new ThemeData(
        primaryColor: Colors.grey[850],
        buttonTheme: ButtonThemeData(
          textTheme: ButtonTextTheme.primary,
        ),
        //accentColor: Colors.cyan[600],
      ),
      home: homepage,
      routes: <String, WidgetBuilder>{
        'login': (BuildContext context) => LoginScreen(),
        'incident': (BuildContext context) => CommandScreen(tabIndex: 0),
        'plan': (BuildContext context) => CommandScreen(tabIndex: 1),
        'incidentlist': (BuildContext context) => IncidentsScreen(),
        'map': (BuildContext context) => MapScreen(),
      },
    ),
  ));
}

Future<Widget> getHome(login) async {
  UserService userService = UserService();

  String token = await userService.getToken();
  print("Token from User service $token");

  if (token != null) {
    return IncidentsScreen();
  } else {
    return LoginScreen();
  }
}
