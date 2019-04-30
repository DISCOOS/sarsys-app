import 'package:flutter/material.dart';
import 'screens/LoginScreen.dart';
import 'screens/IncidentlistScreen.dart';
import 'screens/IncidentScreen.dart';
import 'screens/MapScreen.dart';
import 'Services/UserService.dart';

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
      'incident': (BuildContext context) => IncidentScreen(),
      'incidentlist': (BuildContext context) => IncidentlistScreen(),
      'map': (BuildContext context) => MapScreen(),
    },
  ));
}

Future<Widget> getHome(login) async {
  UserService userService = UserService();

  String token = await userService.getToken();
  print("Token from User service $token");

  if (token != null) {
    return IncidentlistScreen();
  } else {
    return LoginScreen();
  }
}
