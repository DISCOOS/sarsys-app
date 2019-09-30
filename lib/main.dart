import 'package:SarSys/widgets/fatal_error_app.dart';
import 'package:SarSys/widgets/sarsys_app.dart';
import 'package:SarSys/widgets/screen_report.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

void main() async {
  final Client client = Client();

  // Required since provider need access to service bindings prior to calling 'runApp()'
  WidgetsFlutterBinding.ensureInitialized();

  // Build and initialize bloc provider
  final controller = BlocProviderController.build(client, demo: DemoParams(true));
  controller.init().then((_) {
    runAppWithCatcher(
      _buildApp(controller),
      controller.configProvider.bloc.config.sentryDns,
    );
//  runApp(_buildApp(controller));
  }).catchError((error, stackTrace) {
    runApp(FatalErrorApp(
      error: error,
      stackTrace: stackTrace,
    ));
  });
}

// Build SarSys app with given controller
Widget _buildApp(BlocProviderController controller) {
  // Listen for controller build events
  controller.onChange.listen(
    (state) => _rebuildApp(state, controller),
  );

  // Called once upon start of app
  return _createApp(controller);
}

Future _rebuildApp(BlocProviderControllerState state, BlocProviderController controller) async {
  if (BlocProviderControllerState.Built == state) {
    // Wait for user and config blocs to initialize
    await controller.init().catchError(
          (error, stackTrace) => Catcher.reportCheckedError(error, stackTrace),
        );

    // Restart app to rehydrate with blocs just built and initiated
    runAppWithCatcher(
      _createApp(controller),
      controller.configProvider.bloc.config.sentryDns,
    );
  }
}

// Convenience method for creating SarSysApp
SarSysApp _createApp(BlocProviderController controller) {
  return SarSysApp(
    key: UniqueKey(),
    controller: controller,
    navigatorKey: Catcher.navigatorKey,
  );
}

// Convenience method for running apps with Catcher
void runAppWithCatcher(Widget app, String sentryDns) {
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
      ScreenReportMode(),
      [SentryHandler(sentryDns), ConsoleHandler(enableStackTrace: true)],
      explicitExceptionReportModesMap: explicitReportModesMap,
      explicitExceptionHandlersMap: explicitExceptionHandlersMap,
      localizationOptions: [localizationOptions],
    ),
    releaseConfig: CatcherOptions(
      ScreenReportMode(),
      [SentryHandler(sentryDns)],
      explicitExceptionReportModesMap: explicitReportModesMap,
      explicitExceptionHandlersMap: explicitExceptionHandlersMap,
      localizationOptions: [localizationOptions],
    ),
  );
}
