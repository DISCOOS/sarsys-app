import 'dart:async';

import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/app_config/domain/repositories/app_config_repository.dart';
import 'package:SarSys/features/app_config/data/services/app_config_service.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';

import '../../../../blocs/core.dart';
import '../../../../blocs/mixins.dart';

typedef void AppConfigCallback(VoidCallback fn);

class AppConfigBloc extends BaseBloc<AppConfigCommand, AppConfigState, AppConfigBlocError>
    with InitableBloc<AppConfig>, LoadableBloc<AppConfig>, UpdatableBloc<AppConfig> {
  AppConfigBloc(this.repo);
  final AppConfigRepository repo;

  AppConfigService get service => repo.service;

  @override
  AppConfigEmpty get initialState => AppConfigEmpty();

  /// Check if [config] is empty
  bool get isReady => repo.isReady && repo.state?.isDeleted != null;

  /// Get config
  AppConfig get config => repo.config;

  /// Initialize config from [service]
  @override
  Future<AppConfig> init({bool local = false}) async => dispatch(InitAppConfig(
        local: local,
      ));

  /// Load config from [service]
  @override
  Future<AppConfig> load() async => dispatch(LoadAppConfig());

  /// Load config from [service]
  @override
  Future<AppConfig> update(AppConfig data) async => dispatch(UpdateAppConfig(data));

  /// Update with given settings
  Future<AppConfig> updateWith({
    bool demo,
    String demoRole,
    bool onboarded,
    bool firstSetup,
    String orgId,
    String divId,
    String depId,
    List<String> talkGroups,
    String talkGroupCatalog,
    bool storage,
    bool locationWhenInUse,
    int mapCacheTTL,
    int mapCacheCapacity,
    String locationAccuracy,
    int locationFastestInterval,
    int locationSmallestDisplacement,
    bool keepScreenOn,
    bool callsignReuse,
    List<String> units,
    SecurityType securityType,
    SecurityMode securityMode,
    List<String> trustedDomains,
    int securityLockAfter,
  }) async {
    if (!isReady) return Future.error("AppConfig not ready");
    final config = this.config.copyWith(
          demo: demo,
          demoRole: demoRole,
          onboarded: onboarded,
          firstSetup: firstSetup,
          orgId: orgId,
          divId: divId,
          depId: depId,
          talkGroups: talkGroups,
          talkGroupCatalog: talkGroupCatalog,
          storage: storage,
          locationWhenInUse: locationWhenInUse,
          mapCacheTTL: mapCacheTTL,
          mapCacheCapacity: mapCacheCapacity,
          locationAccuracy: locationAccuracy,
          locationFastestInterval: locationFastestInterval,
          locationSmallestDisplacement: locationSmallestDisplacement,
          keepScreenOn: keepScreenOn,
          callsignReuse: callsignReuse,
          units: units,
          securityType: securityType,
          securityMode: securityMode,
          securityLockAfter: securityLockAfter,
          trustedDomains: trustedDomains,
        );
    return update(config);
  }

  Future<AppConfig> delete() {
    return dispatch<AppConfig>(DeleteAppConfig());
  }

  @override
  Stream<AppConfigState> execute(AppConfigCommand command) async* {
    if (command is InitAppConfig) {
      yield await _init(command);
    } else if (command is LoadAppConfig) {
      yield await _load(command);
    } else if (command is UpdateAppConfig) {
      yield await _update(command);
    } else if (command is DeleteAppConfig) {
      yield await _delete(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Future<AppConfigState> _init(InitAppConfig event) async {
    var config = await (event.local ? repo.local() : repo.init());
    return toOK(
      event,
      AppConfigInitialized(config, local: event.local),
      result: config,
    );
  }

  Future<AppConfigState> _load(LoadAppConfig event) async {
    var config = await repo.load();
    return toOK(
      event,
      AppConfigLoaded(config),
      result: config,
    );
  }

  Future<AppConfigState> _update(UpdateAppConfig event) async {
    var config = await repo.update(event.data);
    return toOK(
      event,
      AppConfigUpdated(config),
      result: config,
    );
  }

  Future<AppConfigState> _delete(DeleteAppConfig event) async {
    var config = await repo.delete();
    return toOK(
      event,
      AppConfigDeleted(config),
      result: config,
    );
  }

  // Complete with error and return response as error state to bloc
  AppConfigBlocError createError(Object error, {StackTrace stackTrace}) => AppConfigBlocError(
        error,
        stackTrace: stackTrace,
      );

  @override
  Future<void> close() async {
    await repo.dispose();
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class AppConfigCommand<T> extends BlocCommand<T, T> {
  AppConfigCommand(T data, [props = const []]) : super(data, props);
}

class InitAppConfig extends AppConfigCommand<AppConfig> {
  final bool local;
  InitAppConfig({this.local = false}) : super(null);

  @override
  String toString() => 'InitAppConfig {local: $local}';
}

class LoadAppConfig extends AppConfigCommand<AppConfig> {
  LoadAppConfig() : super(null);

  @override
  String toString() => 'LoadAppConfig {}';
}

class UpdateAppConfig extends AppConfigCommand<AppConfig> {
  UpdateAppConfig(AppConfig data) : super(data);

  @override
  String toString() => 'UpdateAppConfig {data: $data}';
}

class DeleteAppConfig extends AppConfigCommand<AppConfig> {
  DeleteAppConfig() : super(null);

  @override
  String toString() => 'DeleteAppConfig {}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class AppConfigState<T> extends BlocEvent {
  AppConfigState(
    T data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  isEmpty() => this is AppConfigEmpty;
  isInitialized() => this is AppConfigInitialized;
  isLoaded() => this is AppConfigLoaded;
  isUpdated() => this is AppConfigUpdated;
  isDeleted() => this is AppConfigDeleted;
  isError() => this is AppConfigBlocError;
}

class AppConfigEmpty extends AppConfigState<Null> {
  AppConfigEmpty() : super(null);

  @override
  String toString() => 'AppConfigEmpty';
}

class AppConfigInitialized extends AppConfigState<AppConfig> {
  final bool local;
  AppConfigInitialized(AppConfig config, {this.local = false}) : super(config);

  @override
  String toString() => 'AppConfigInitialized {config: $data, local: $local}';
}

class AppConfigLoaded extends AppConfigState<AppConfig> {
  AppConfigLoaded(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigLoaded {config: $data}';
}

class AppConfigUpdated extends AppConfigState<AppConfig> {
  AppConfigUpdated(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigUpdated {config: $data}';
}

class AppConfigDeleted extends AppConfigState<AppConfig> {
  AppConfigDeleted(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigDeleted {config: $data}';
}

/// ---------------------
/// Error States
/// ---------------------
class AppConfigBlocError extends AppConfigState<Object> {
  AppConfigBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class AppConfigBlocException implements Exception {
  AppConfigBlocException(this.state, {this.command, this.stackTrace});
  final AppConfigState state;
  final StackTrace stackTrace;
  final AppConfigCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
