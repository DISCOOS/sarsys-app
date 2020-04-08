import 'dart:async';

import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';

typedef void AppConfigCallback(VoidCallback fn);

class AppConfigBloc extends Bloc<AppConfigCommand, AppConfigState> {
  final AppConfigService service;

  AppConfig _config;

  AppConfigBloc(this.service);

  @override
  AppConfigState get initialState => AppConfigEmpty();

  /// Check if [config] is empty
  bool get isReady => _config != null;

  /// Get config
  AppConfig get config => _config;

  /// Initialize config from [service]
  Future<AppConfig> init() async => _dispatch(InitAppConfig());

  /// Load config from [service]
  Future<AppConfig> load() async => _dispatch(LoadAppConfig());

  /// Update given settings
  Future<AppConfig> update({
    String securityPin,
    SecurityType securityType,
    SecurityMode securityMode,
    bool demo,
    String demoRole,
    bool onboarded,
    bool firstSetup,
    String organization,
    String division,
    String department,
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
  }) async {
    if (!isReady) return Future.error("AppConfig not ready");
    final config = this.config.copyWith(
          securityType: securityType,
          securityMode: securityMode,
          demo: demo,
          demoRole: demoRole,
          onboarded: onboarded,
          firstSetup: firstSetup,
          organization: organization,
          division: division,
          department: department,
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
        );
    return _dispatch(UpdateAppConfig(config));
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(AppConfigCommand<T> command) {
    dispatch(command);
    return command.callback.future;
  }

  @override
  Stream<AppConfigState> mapEventToState(AppConfigCommand command) async* {
    if (command is InitAppConfig) {
      yield await _init(command);
    } else if (command is LoadAppConfig) {
      yield await _load(command);
    } else if (command is UpdateAppConfig) {
      yield await _update(command);
    } else if (command is RaiseAppConfigError) {
      yield _toError(command, command.data);
    } else {
      yield _toError(command, AppConfigError("Unsupported $command"));
    }
  }

  Future<AppConfigState> _init(InitAppConfig event) async {
    var response = await service.init();
    if (response.is200) {
      _config = response.body;
      return _toOK(
        event,
        AppConfigInitialized(_config),
        result: _config,
      );
    }
    return _toError(event, response);
  }

  Future<AppConfigState> _load(LoadAppConfig event) async {
    var response = await service.load();
    if (response.is200) {
      _config = response.body;
      return _toOK(
        event,
        AppConfigLoaded(_config),
        result: _config,
      );
    }
    return _toError(event, response);
  }

  Future<AppConfigState> _update(UpdateAppConfig event) async {
    var response = await service.update(event.data);
    if (response.is200) {
      _config = event.data;
      return _toOK(
        event,
        AppConfigUpdated(_config),
        result: _config,
      );
    }
    return _toError(event, response);
  }

  // Complete request and return given state to bloc
  AppConfigState _toOK(AppConfigCommand event, AppConfigState state, {AppConfig result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  AppConfigState _toError(AppConfigCommand event, Object response) {
    final error = AppConfigError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    dispatch(RaiseAppConfigError(AppConfigError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class AppConfigCommand<T> extends Equatable {
  final T data;
  final Completer<T> callback = Completer();

  AppConfigCommand(this.data, [props = const []]) : super([data, ...props]);
}

class InitAppConfig extends AppConfigCommand<AppConfig> {
  InitAppConfig() : super(null);

  @override
  String toString() => 'InitAppConfig {}';
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

class RaiseAppConfigError extends AppConfigCommand<AppConfigError> {
  RaiseAppConfigError(data) : super(data);

  @override
  String toString() => 'RaiseAppConfigError {data: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class AppConfigState<T> extends Equatable {
  final T data;

  AppConfigState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is AppConfigEmpty;
  isInitialized() => this is AppConfigInitialized;
  isLoaded() => this is AppConfigLoaded;
  isUpdated() => this is AppConfigUpdated;
  isException() => this is AppConfigException;
  isError() => this is AppConfigError;
}

class AppConfigEmpty extends AppConfigState<Null> {
  AppConfigEmpty() : super(null);

  @override
  String toString() => 'AppConfigEmpty';
}

class AppConfigInitialized extends AppConfigState<AppConfig> {
  AppConfigInitialized(AppConfig config) : super(config);

  @override
  String toString() => 'AppConfigInitialized';
}

class AppConfigLoaded extends AppConfigState<AppConfig> {
  AppConfigLoaded(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigLoaded';
}

class AppConfigUpdated extends AppConfigState<AppConfig> {
  AppConfigUpdated(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigUpdated';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class AppConfigException extends AppConfigState<Object> {
  final StackTrace trace;
  AppConfigException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'AppConfigException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class AppConfigError extends AppConfigException {
  final StackTrace trace;
  AppConfigError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'AppConfigError {data: $data}';
}
