import 'package:SarSys/models/AppConfig.dart';
import 'package:catcher/catcher_plugin.dart';
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
  final providers = Providers.build(client, mock: true);
  final Widget homepage = await getHome(providers);

  // Initialize app-config
  final AppConfig config = await providers.configProvider.bloc.fetch();

  //runAppWithCatcher(app, config);

  runApp(
    BlocProviderTree(
      blocProviders: providers.all,
      child: MaterialApp(
        navigatorKey: Catcher.navigatorKey,
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
        ],
      ),
    ),
  );
}

Future<Widget> getHome(Providers providers) async {
  if (await providers.userProvider.bloc.init()) {
    return IncidentsScreen();
  } else {
    return LoginScreen();
  }
}

void runAppWithCatcher(Widget app, AppConfig config) {
  final localizationOptions = LocalizationOptions("nb",
      notificationReportModeTitle: "En feil har oppstått",
      notificationReportModeContent: "Klikk her for å sende feilrapport til brukerstøtte",
      dialogReportModeTitle: "Feilmelding",
      dialogReportModeDescription: "Oi, en feil har dessverre oppstått. "
          "Jeg har klargjort en rapport som kan sendes til brukerstøtte. "
          "Klikk på Godta for å sende rapporten eller Avbryt for å avvise.",
      dialogReportModeAccept: "Godta",
      dialogReportModeCancel: "Avbryt",
      pageReportModeTitle: "Feilmelding",
      pageReportModeDescription: "Oi, en feil har dessverre oppstått. "
          "Jeg har klargjort en rapport som kan sendes til brukerstøtte. "
          "Klikk på Godta for å sende rapporten eller Avbryt for å avvise.",
      pageReportModeAccept: "Godta",
      pageReportModeCancel: "Avbryt");

  Catcher(
    app,
    debugConfig: CatcherOptions(
      PageReportMode(),
      [ConsoleHandler(enableStackTrace: true)],
      localizationOptions: [localizationOptions],
    ),
    releaseConfig: CatcherOptions(
      PageReportMode(),
      [SentryHandler(config.sentryDns)],
      localizationOptions: [localizationOptions],
    ),
  );
}
