import 'package:flutter/material.dart';

import 'Services/UserService.dart';
import 'screens/CommandScreen.dart';
import 'screens/IncidentsScreen.dart';
import 'screens/LoginScreen.dart';
import 'screens/MapScreen.dart';

void main() async {
  Widget homepage = await getHome(false);

  runApp(MaterialApp(
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
      'plan': (BuildContext context) => CommandScreen(tabIndex: 0),
      'incidentlist': (BuildContext context) => IncidentsScreen(),
      'map': (BuildContext context) => MapScreen(),
    },
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
