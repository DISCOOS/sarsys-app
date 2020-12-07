import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

abstract class AppConfigRepository implements StatefulRepository<int, AppConfig, AppConfigService> {
  int get version;
  String get assets;
  AppConfigService get service;

  /// Get current [AppConfig] instance
  AppConfig get config => this[version];

  /// Get current state
  StorageState<AppConfig> get state => getState(version);

  /// Initialize from [assets] and push to remote
  Future<AppConfig> init({
    Completer<Iterable<AppConfig>> onRemote,
  });

  /// Create local instance from [assets]
  ///
  /// Same as [init], without push to remote
  Future<AppConfig> local();

  /// Load from [AppConfig] from [service].
  Future<AppConfig> load({
    Completer<Iterable<AppConfig>> onRemote,
  });
}

class AppConfigServiceException extends ServiceException {
  AppConfigServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
