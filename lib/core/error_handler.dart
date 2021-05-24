import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'data/services/connectivity_service.dart';
import 'data/streams.dart';
import 'domain/repository.dart';

class SarSysApp {
  static void reportCheckedError(dynamic error, dynamic stackTrace) {
    switch (error.runtimeType) {
      case HttpExceptionWithStatus:
        switch ((error as HttpExceptionWithStatus).statusCode) {
          case HttpStatus.requestTimeout:
            ConnectivityService().onTimeout(error);
            return;
        }
        break;
      case TimeoutException:
      case RepositoryTimeoutException:
      case StreamRequestTimeoutException:
        ConnectivityService().onTimeout(error);
        return;
    }
    SarSysApp.reportCheckedError(error, stackTrace);
  }
}
