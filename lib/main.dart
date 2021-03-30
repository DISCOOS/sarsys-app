import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/presentation/widgets/fatal_error_app.dart';
import 'package:SarSys/core/presentation/widgets/network_sensitive.dart';
import 'package:SarSys/core/presentation/widgets/sarsys_app.dart';
import 'package:SarSys/core/presentation/widgets/screen_report.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/catcher.dart';
import 'package:SarSys/core/app_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'core/domain/repository.dart';
import 'features/settings/domain/entities/AppConfig.dart';
import 'features/settings/presentation/blocs/app_config_bloc.dart';
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
  final controller = AppController.build(client);

  // SarSysApp widget will handle rebuilds
  controller.configure().then((_) {
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
  AppController controller,
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

Catcher _catcher;

// Convenience method for running apps with Catcher
void runAppWithCatcher(Widget app, AppController controller) {
  final sentryDns = controller.bloc<AppConfigBloc>().config.sentryDns;

  // Catch unhandled bloc and repository exceptions
  BlocSupervisor.delegate = controller.delegate;
  RepositorySupervisor.delegate = AppRepositoryDelegate();

  _catcher = Catcher(
    rootWidget: app,
    debugConfig: _toCatcherDebugConfig(sentryDns),
    releaseConfig: _toCatcherReleaseConfig(sentryDns),
    navigatorKey: NavigationService.navigatorKey,
  );
}

void updateCatcherConfig(AppConfig config) {
  if (_catcher != null) {
    _catcher.updateConfig(
      debugConfig: _toCatcherDebugConfig(config.sentryDns),
      releaseConfig: _toCatcherReleaseConfig(config.sentryDns),
    );
  }
}

CatcherOptions _toCatcherReleaseConfig(String sentryDns) {
  return CatcherOptions(
    ScreenReportMode(),
    [SentryHandler(SentryClient(SentryOptions(dsn: sentryDns)))],
    explicitExceptionReportModesMap: _catcherExplicitReportModesMap,
    explicitExceptionHandlersMap: _catcherExplicitExceptionHandlersMap,
    localizationOptions: [_catcherLocalizationOptions],
  );
}

CatcherOptions _toCatcherDebugConfig(String sentryDns) {
  return CatcherOptions(
    ScreenReportMode(),
    [SentryHandler(SentryClient(SentryOptions(dsn: sentryDns))), ConsoleHandler(enableStackTrace: true)],
    explicitExceptionReportModesMap: _catcherExplicitReportModesMap,
    explicitExceptionHandlersMap: _catcherExplicitExceptionHandlersMap,
    localizationOptions: [_catcherLocalizationOptions],
  );
}

final _catcherLocalizationOptions = LocalizationOptions(
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

var _catcherIgnorerExceptions = [
  // Silence connection errors
  "ClientException",
  "SocketException",
  // Silence flutter_cache_manager exceptions
  "Could not instantiate image codec",
  "Couldn't download or retrieve file",
  "HttpException: Invalid statusCode: 500, uri = https://opencache.statkart.no",
  "HttpException: Invalid statusCode: 500, uri = https://opencache2.statkart.no",
  "HttpException: Invalid statusCode: 500, uri = https://opencache3.statkart.no",
  "HttpException: Invalid statusCode: 502, uri = https://opencache.statkart.no",
  "HttpException: Invalid statusCode: 502, uri = https://opencache2.statkart.no",
  "HttpException: Invalid statusCode: 502, uri = https://opencache3.statkart.no",
  "HttpException: Invalid statusCode: 504, uri = https://opencache.statkart.no",
  "HttpException: Invalid statusCode: 504, uri = https://opencache2.statkart.no",
  "HttpException: Invalid statusCode: 504, uri = https://opencache3.statkart.no",
  // Silence general map tile fetch failures thrown by FlutterMap
  "FetchFailure",
  "FileSystemException: Cannot open file",
  "OS Error: No such file or directory",
  "Connection closed while receiving data",
  "Connection closed before full header was received",
  "OS Error: Connection timed out",
  "OS Error: Software caused connection abort",
  "HandshakeException: Connection terminated during handshake",
];

final Map<String, ReportMode> _catcherExplicitReportModesMap = Map.fromIterable(
  _catcherIgnorerExceptions,
  key: (e) => e,
  value: (_) => SilentReportMode(),
);

final Map<String, ReportHandler> _catcherExplicitExceptionHandlersMap = Map.fromIterable(
  _catcherIgnorerExceptions,
  key: (e) => e,
  value: (_) => ConsoleHandler(),
);

class AppRepositoryDelegate implements RepositoryDelegate {
  @override
  void onError(Repository repo, Object error, StackTrace stackTrace) {
    Catcher.reportCheckedError(error, stackTrace);
  }
}
