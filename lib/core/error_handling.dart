import 'dart:async';

import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_mode.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

bool get isInDebugMode {
  bool inDebugMode = false;
  assert(inDebugMode = true);
  return inDebugMode;
}

void runAppWithErrorHandling(final Widget app, final SentryClient client) {
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (isInDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      Zone.current.handleUncaughtError(details.exception, details.stack);
    }
  };

  runZoned<Future<Null>>(() async {
    runApp(app);
  }, onError: (error, stackTrace) async {
    await _reportError(client, error, stackTrace);
  });
}

/// Reports [error] along with its [stackTrace] to Sentry.io.
Future<Null> _reportError(final SentryClient client, dynamic error, dynamic stackTrace) async {
  print('Caught error: $error');

  // Errors thrown in development mode are unlikely to be interesting. You can
  // check if you are running in dev mode using an assertion and omit sending
  // the report.
  if (isInDebugMode) {
    if (stackTrace != null) print(stackTrace);
    print('In dev mode. Not sending report to Sentry.io.');
    return;
  }

  print('Reporting to Sentry.io...');

  final SentryResponse response = await client.captureException(
    exception: error,
    stackTrace: stackTrace,
  );

  if (response.isSuccessful) {
    print('Success! Event ID: ${response.eventId}');
  } else {
    print('Failed to report to Sentry.io: ${response.error}');
  }
}
