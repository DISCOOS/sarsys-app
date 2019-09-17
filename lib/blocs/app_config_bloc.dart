import 'dart:async';

import 'package:SarSys/models/AppConfig.dart';
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

  /// Fetch config from [service]
  Future<AppConfig> fetch() async {
    var response = await service.fetch();
    if (response.is200) {
      return _dispatch(FetchAppConfig(response.body));
    }
    dispatch(RaiseAppConfigError(response));
    return Future.error(response);
  }

  /// Update given settings
  Future<AppConfig> update({
    bool demo,
    String demoRole,
    bool onboarding,
    String district,
    String department,
    String talkGroups,
    bool storage,
    bool locationWhenInUse,
    int mapCacheTTL,
    int mapCacheCapacity,
    String locationAccuracy,
    int locationFastestInterval,
    int locationSmallestDisplacement,
  }) async {
    if (!isReady) return Future.error("AppConfig not ready");
    final config = this.config.copyWith(
          demo: demo,
          demoRole: demoRole,
          onboarding: onboarding,
          district: district,
          department: department,
          talkGroups: talkGroups,
          storage: storage,
          locationWhenInUse: locationWhenInUse,
          mapCacheTTL: mapCacheTTL,
          mapCacheCapacity: mapCacheCapacity,
          locationAccuracy: locationAccuracy,
          locationFastestInterval: locationFastestInterval,
          locationSmallestDisplacement: locationSmallestDisplacement,
        );
    var response = await service.save(config);
    if (response.is204) {
      return _dispatch(UpdateAppConfig(config));
    }
    dispatch(RaiseAppConfigError(response));
    return Future.error(response);
  }

  @override
  Stream<AppConfigState> mapEventToState(AppConfigCommand command) async* {
    if (command is FetchAppConfig) {
      _config = command.data;
      yield _toOK(command, AppConfigLoaded(_config), result: _config);
    } else if (command is UpdateAppConfig) {
      _config = command.data;
      yield _toOK(command, AppConfigUpdated(_config), result: _config);
    } else if (command is RaiseAppConfigError) {
      yield _toError(command, command.data);
    } else {
      yield _toError(command, AppConfigError("Unsupported $command"));
    }
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(AppConfigCommand<T> command) {
    dispatch(command);
    return command.callback.future;
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

class FetchAppConfig extends AppConfigCommand<AppConfig> {
  FetchAppConfig(AppConfig data) : super(data);

  @override
  String toString() => 'FetchAppConfig';
}

class UpdateAppConfig extends AppConfigCommand<AppConfig> {
  UpdateAppConfig(AppConfig data) : super(data);

  @override
  String toString() => 'UpdateAppConfig';
}

class RaiseAppConfigError extends AppConfigCommand<AppConfigError> {
  RaiseAppConfigError(data) : super(data);

  @override
  String toString() => 'RaiseAppConfigError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class AppConfigState<T> extends Equatable {
  final T data;

  AppConfigState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is AppConfigEmpty;
  isInit() => this is AppConfigInit;
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

class AppConfigInit extends AppConfigState<AppConfig> {
  AppConfigInit(AppConfig config) : super(config);

  @override
  String toString() => 'AppConfigInit';
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
