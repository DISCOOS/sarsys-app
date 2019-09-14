import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:SarSys/core/provider_controller.dart';
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
  final providers = await ProviderController.build(
    client,
    demo: DemoParams(true),
  ).init();

  // Initialize app-config
  runApp(_buildApp(providers));
//  runAppWithCatcher(
//    _buildApp(providers, homepage),
//    await providers.configProvider.bloc.fetch(),
//  );
}

Widget _buildApp(ProviderController providers) {
  /// Initialize provider after build events
  providers.onChange.listen(
    (state) => {if (ProviderControllerState.Built == state) providers.init()},
  );

  return MaterialApp(
    navigatorKey: Catcher.navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'SarSys',
    theme: ThemeData(
      primaryColor: Colors.grey[850],
      buttonTheme: ButtonThemeData(
        height: 36.0,
        textTheme: ButtonTextTheme.primary,
      ),
    ),
    home: getHome(providers),
    builder: (context, child) {
      // will rebuild when blocs are rebuilt with Providers.rebuild
      return StreamBuilder<ProviderControllerState>(
          stream: providers.onChange,
          builder: (context, snapshot) {
            return BlocProviderTree(
              blocProviders: providers.all,
              child: child,
            );
          });
    },
    routes: <String, WidgetBuilder>{
      'login': (BuildContext context) => LoginScreen(),
      'incident': (BuildContext context) => CommandScreen(tabIndex: 0),
      'units': (BuildContext context) => CommandScreen(tabIndex: 1),
      'devices': (BuildContext context) => CommandScreen(tabIndex: 2),
      'incidents': (BuildContext context) => IncidentsScreen(),
      'settings': (BuildContext context) => SettingsScreen(),
      'map': (BuildContext context) => _toMapScreen(context),
    },
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

Widget getHome(ProviderController providers) {
  if (providers.configProvider.bloc.config.onboarding)
    return OnboardingScreen();
  else if (providers.userProvider.bloc.isAuthenticated)
    return IncidentsScreen();
  else
    return LoginScreen();
}

void runAppWithCatcher(Widget app, AppConfig config) {
  final localizationOptions = LocalizationOptions(
    "nb",
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
    pageReportModeCancel: "Avbryt",
  );

  var exceptions = [
    // Silence map tile cache host lookup
    "SocketException: Failed host lookup",
    // Silence map tile fetch failures thrown by FlutterMap
    "Couldn't download or retrieve file", "FetchFailure",
    "SocketException: OS Error: Software caused connection abort",
    "Connection closed while receiving data",
    // Silence Overlay assertion errors thrown by form_field_builder.
    // See https://github.com/danvick/flutter_chips_input/pull/13 for proposed fix.
    "package:flutter/src/widgets/overlay.dart': failed assertion: line 133 pos 12: '_overlay != null': is not true."
  ];

  final Map<String, ReportMode> explicitReportModesMap = Map.fromIterable(
    exceptions,
    key: (e) => e,
    value: (_) => SilentReportMode(),
  );

  final Map<String, ReportHandler> explicitExceptionHandlersMap = Map.fromIterable(
    exceptions,
    key: (e) => e,
    value: (_) => ConsoleHandler(),
  );

  Catcher(
    app,
    debugConfig: CatcherOptions(
      PageReportMode(),
      [SentryHandler(config.sentryDns), ConsoleHandler(enableStackTrace: true)],
      explicitExceptionReportModesMap: explicitReportModesMap,
      explicitExceptionHandlersMap: explicitExceptionHandlersMap,
      localizationOptions: [localizationOptions],
    ),
    releaseConfig: CatcherOptions(
      PageReportMode(),
      [SentryHandler(config.sentryDns)],
      explicitExceptionReportModesMap: explicitReportModesMap,
      explicitExceptionHandlersMap: explicitExceptionHandlersMap,
      localizationOptions: [localizationOptions],
    ),
  );
}
