import 'dart:async';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/features/app_config/data/services/app_config_service.dart';
import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';

abstract class AppConfigRepository implements ConnectionAwareRepository<int, AppConfig> {
  int get version;
  String get assets;
  AppConfigService get service;

  /// Get current [AppConfig] instance
  AppConfig get config => this[version];

  /// Get current state
  StorageState<AppConfig> get state => getState(version);

  /// Initialize from [assets] and push to remote
  Future<AppConfig> init();

  /// Create local instance from [assets]
  ///
  /// Same as [init], without push to remote
  Future<AppConfig> local();

  /// Load from [AppConfig] from [service].
  Future<AppConfig> load();

  /// Push [config] to [service]
  Future<AppConfig> update(AppConfig config);

  /// Delete [config] from [service]
  Future<AppConfig> delete();
}

class AppConfigServiceException extends RepositoryException {
  AppConfigServiceException(
    Object error, {
    this.response,
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);
  final ServiceResponse response;

  @override
  String toString() {
    return 'AppConfigServiceException { $message, response: $response, stackTrace: $stackTrace}';
  }
}
