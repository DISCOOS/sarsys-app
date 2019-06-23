import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/mock/tracking.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'blocs/device_bloc.dart';
import 'blocs/tracking_bloc.dart';
import 'blocs/unit_bloc.dart';
import 'mock/devices.dart';
import 'mock/incidents.dart';
import 'mock/users.dart';
import 'services/tracking_service.dart';
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

  // Configure Unit service
  final UnitService unitService = kReleaseMode ? UnitService(apiUrl) : UnitServiceMock.build(15);
  final UnitBloc unitBloc = UnitBloc(unitService);

  // Configure Device service
  final DeviceService deviceService = kReleaseMode ? DeviceService(apiUrl) : DeviceServiceMock.build(30);
  final DeviceBloc deviceBloc = DeviceBloc(deviceService);

  // Configure Tracking service
  final TrackingService trackingService =
      kReleaseMode ? TrackingService(apiUrl) : TrackingServiceMock.build(incidentBloc, 30);
  final TrackingBloc trackingBloc = TrackingBloc(trackingService);

  final Widget homepage = await getHome(userBloc);

  runApp(BlocProviderTree(
    blocProviders: [
      BlocProvider<UserBloc>(bloc: userBloc),
      BlocProvider<IncidentBloc>(bloc: incidentBloc),
      BlocProvider<UnitBloc>(bloc: unitBloc),
      BlocProvider<DeviceBloc>(bloc: deviceBloc),
      BlocProvider<TrackingBloc>(bloc: trackingBloc),
    ],
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
          'map': (BuildContext context) => MapScreen(center: ModalRoute.of(context).settings.arguments),
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
