import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';

typedef void AppConfigCallback(VoidCallback fn);

class AppConfigBloc extends BaseBloc<AppConfigCommand, AppConfigState, AppConfigBlocError>
    with
        InitableBloc<AppConfig>,
        LoadableBloc<AppConfig>,
        UpdatableBloc<AppConfig>,
        ConnectionAwareBloc<int, AppConfig> {
  AppConfigBloc(this.repo, BlocEventBus bus) : super(bus: bus);
  final AppConfigRepository repo;

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [repo];

  AppConfigService get service => repo.service;

  @override
  AppConfigEmpty get initialState => AppConfigEmpty();

  /// Check if [config] is empty
  bool get isReady => repo.isReady && repo.state != null && repo.state.isDeleted != true;

  /// Get config
  AppConfig get config => repo.config;

  /// Get all [AppConfig]s
  Iterable<AppConfig> get values => repo.values;

  /// Get [AppConfig] from [uuid]
  AppConfig operator [](int uuid) => repo[uuid];

  /// Initialize config from [service]
  @override
  Future<AppConfig> init({bool local = false}) async => dispatch(InitAppConfig(
        isLocal: local,
      ));

  /// Load config from [service]
  @override
  Future<AppConfig> load() async => dispatch(LoadAppConfig());

  /// Load config from [service]
  @override
  Future<AppConfig> update(AppConfig data) async => dispatch(
        UpdateAppConfig(data),
      );

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
    bool locationAlways,
    bool locationWhenInUse,
    bool activityRecognition,
    bool locationStoreLocally,
    bool locationAllowSharing,
    int mapCacheTTL,
    bool mapRetinaMode,
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
          locationAlways: locationAlways,
          locationWhenInUse: locationWhenInUse,
          activityRecognition: activityRecognition,
          locationStoreLocally: locationStoreLocally,
          locationAllowSharing: locationAllowSharing,
          mapCacheTTL: mapCacheTTL,
          mapRetinaMode: mapRetinaMode,
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
      yield* _init(command);
    } else if (command is LoadAppConfig) {
      yield* _load(command);
    } else if (command is UpdateAppConfig) {
      yield* _update(command);
    } else if (command is DeleteAppConfig) {
      yield* _delete(command);
    } else if (command is _StateChange) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<AppConfigState> _init(InitAppConfig event) async* {
    var config = await (event.isLocal ? repo.local() : repo.init());
    yield toOK(
      event,
      AppConfigInitialized(
        config,
        isLocal: event.isLocal,
      ),
      result: config,
    );
  }

  Stream<AppConfigState> _load(LoadAppConfig event) async* {
    // Fetch cached and handle
    // response from remote when ready
    final onRemote = Completer<Iterable<AppConfig>>();
    final config = await repo.load(
      onRemote: onRemote,
    );
    yield toOK(
      event,
      AppConfigLoaded(config),
      result: config,
    );
    // Notify when states was fetched from remote storage?
    onComplete(
      [onRemote.future],
      toState: (_) => AppConfigLoaded(
        config,
        isLocal: false,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        event,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<AppConfigState> _update(UpdateAppConfig event) async* {
    final config = await repo.apply(
      event.data,
    );
    yield toOK(
      event,
      AppConfigUpdated(config),
      result: config,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(config.version)],
      toState: (_) => AppConfigUpdated(
        repo.config,
        isLocal: false,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        event,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<AppConfigState> _delete(DeleteAppConfig event) async* {
    var config = await repo.delete(repo.version);
    yield toOK(
      event,
      AppConfigDeleted(config),
      result: config,
    );
    // Notify when all states are remote
    onComplete(
      [repo.onRemote(config.version, require: false)],
      toState: (_) => AppConfigDeleted(
        config,
        isLocal: false,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        event,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  // Complete with error and return response as error state to bloc
  AppConfigBlocError createError(Object error, {StackTrace stackTrace}) => AppConfigBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
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
  InitAppConfig({this.isLocal = false}) : super(null);
  final bool isLocal;
  bool get isRemote => !isLocal;

  @override
  String toString() => '$runtimeType {local: $isLocal}';
}

class LoadAppConfig extends AppConfigCommand<AppConfig> {
  LoadAppConfig() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class UpdateAppConfig extends AppConfigCommand<AppConfig> {
  UpdateAppConfig(AppConfig data) : super(data);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class DeleteAppConfig extends AppConfigCommand<AppConfig> {
  DeleteAppConfig() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class _StateChange extends AppConfigCommand<AppConfigState> {
  _StateChange(
    AppConfigState state,
  ) : super(state);

  @override
  String toString() => '$runtimeType {state: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class AppConfigState<T> extends BlocEvent {
  AppConfigState(
    T data, {
    StackTrace stackTrace,
    props = const [],
    this.isRemote = false,
  }) : super(data, props: [...props, isRemote], stackTrace: stackTrace);

  final bool isRemote;
  bool get isLocal => !isRemote;

  isEmpty() => this is AppConfigEmpty;
  isLoaded() => this is AppConfigLoaded;
  isUpdated() => this is AppConfigUpdated;
  isDeleted() => this is AppConfigDeleted;
  isError() => this is AppConfigBlocError;
  isInitialized() => this is AppConfigInitialized;
}

class AppConfigEmpty extends AppConfigState<Null> {
  AppConfigEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class AppConfigInitialized extends AppConfigState<AppConfig> {
  AppConfigInitialized(
    AppConfig data, {
    bool isLocal = false,
  }) : super(data, isRemote: !isLocal);

  @override
  String toString() => '$runtimeType {config: $data, isLocal: $isLocal}';
}

class AppConfigLoaded extends AppConfigState<AppConfig> {
  AppConfigLoaded(
    AppConfig data, {
    bool isLocal = false,
  }) : super(data, isRemote: !isLocal);

  @override
  String toString() => '$runtimeType {config: $data, isLocal: $isLocal}';
}

class AppConfigUpdated extends AppConfigState<AppConfig> {
  AppConfigUpdated(
    AppConfig data, {
    bool isLocal = false,
  }) : super(data, isRemote: !isLocal);

  @override
  String toString() => '$runtimeType {config: $data, isLocal: $isLocal}';
}

class AppConfigDeleted extends AppConfigState<AppConfig> {
  AppConfigDeleted(
    AppConfig data, {
    bool isLocal = false,
  }) : super(data, isRemote: !isLocal);

  @override
  String toString() => '$runtimeType {config: $data, isLocal: $isLocal}';
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
