import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/navigation_service.dart';
import 'package:SarSys/widgets/fatal_error_app.dart';
import 'package:SarSys/widgets/network_sensitive.dart';
import 'package:SarSys/widgets/sarsys_app.dart';
import 'package:SarSys/widgets/screen_report.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:SarSys/controllers/bloc_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart';

import 'blocs/app_config_bloc.dart';
import 'core/page_state.dart';

void main() async {
  // Required since provider need access to service bindings prior to calling 'runApp()'
  WidgetsFlutterBinding.ensureInitialized();

  // All services are caching using hive
  await Storage.init();

  final client = Client();
  final bucket = await readPageStorageBucket(PageStorageBucket());

  // This will catch any fatal errors before the app is stated
  BlocSupervisor.delegate = FatalErrorAppBlocDelegate();

  // Build and initialize bloc provider
  final controller = BlocController.build(client, demo: DemoParams(true));

  // SarSysApp widget will handle rebuilds
  controller.init().then((_) {
    runAppWithCatcher(
      _createApp(controller, bucket),
      controller,
    );
  }).catchError((error, stackTrace) {
    runApp(FatalErrorApp(
      error: error,
      stackTrace: stackTrace,
    ));
  });
}

// Convenience method for creating SarSysApp
Widget _createApp(
  BlocController controller,
  PageStorageBucket bucket,
) {
  debugPrint("main:_createApp: ${controller.state}");

  // SarSysApp widget calls
  // Phoenix.rebirth to restart
  // after bloc rebuilds
  return Phoenix(
    child: NetworkSensitive(
      child: SarSysApp(
        bucket: bucket,
        controller: controller,
        navigatorKey: NavigationService.navigatorKey,
      ),
    ),
  );
}

// Convenience method for running apps with Catcher
void runAppWithCatcher(Widget app, BlocController controller) {
  final sentryDns = controller.bloc<AppConfigBloc>().config.sentryDns;
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
    // Silence flutter_cache_manager exceptions
    "Could not instantiate image codec",
    "Couldn't download or retrieve file",
    "HttpException: Invalid statusCode: 500, uri = https://opencache.statkart.no",
    "HttpException: Invalid statusCode: 500, uri = https://opencache2.statkart.no",
    "HttpException: Invalid statusCode: 500, uri = https://opencache3.statkart.no",
    // Silence general map tile fetch failures thrown by FlutterMap
    "FetchFailure",
    "FileSystemException: Cannot open file",
    "OS Error: No such file or directory",
    "Connection closed while receiving data",
    "Connection closed before full header was received",
    "SocketException: OS Error: Connection timed out",
    "SocketException: OS Error: Software caused connection abort",
    "HandshakeException: Connection terminated during handshake",
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

  // Catch unhandled bloc and repository exceptions
  BlocSupervisor.delegate = controller.delegate;
  RepositorySupervisor.delegate = AppRepositoryDelegate();

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

class AppRepositoryDelegate implements RepositoryDelegate {
  @override
  void onError(ConnectionAwareRepository repo, Object error, StackTrace stackTrace) {
    Catcher.reportCheckedError(error, stackTrace);
  }
}
