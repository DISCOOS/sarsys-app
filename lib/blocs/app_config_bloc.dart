import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;
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

  /// Initialize if empty
  AppConfigBloc init({AppConfigCallback onInit}) {
    if (!isReady) {
      service.init().then((config) {
        dispatch(InitAppConfig(config));
        if (onInit != null) onInit(() {});
      });
    }
    return this;
  }

  /// Fetch config from [service]
  Future<AppConfig> fetch() async {
    var config = await service.fetch();
    dispatch(FetchAppConfig(config));
    return config;
  }

  /// Update given settings
  Future<AppConfig> update({
    bool onboarding,
    String affiliation,
    bool locationWhenInUse,
  }) async {
    if (!isReady) return Future.error("AppConfig not ready");

    var next = await service.save(config.copyWith(
      onboarding: onboarding,
      affiliation: affiliation,
      locationWhenInUse: locationWhenInUse,
    ));

    dispatch(UpdateAppConfig(next));
    return next;
  }

  @override
  Stream<AppConfigState> mapEventToState(AppConfigCommand command) async* {
    if (command is InitAppConfig) {
      _config = command.data;
      yield AppConfigInit(_config);
    } else if (command is FetchAppConfig || command is UpdateAppConfig) {
      _config = command.data;
      yield AppConfigLoaded(_config);
    } else if (command is RaiseAppConfigError) {
      yield command.data;
    } else {
      yield AppConfigError("Unsupported $command");
    }
  }

  @override
  void onEvent(AppConfigCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<AppConfigCommand, AppConfigState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseAppConfigError(AppConfigError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class AppConfigCommand<T> extends Equatable {
  final T data;

  AppConfigCommand(this.data, [props = const []]) : super([data, ...props]);
}

class InitAppConfig extends AppConfigCommand<AppConfig> {
  InitAppConfig(AppConfig data) : super(data);

  @override
  String toString() => 'InitAppConfig';
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
  isException() => this is AppConfigException;
  isError() => this is AppConfigError;
}

class AppConfigEmpty extends AppConfigState<Null> {
  AppConfigEmpty() : super(null);

  @override
  String toString() => 'AppConfigEmpty';
}

class AppConfigLoaded extends AppConfigState<AppConfig> {
  AppConfigLoaded(AppConfig data) : super(data);

  @override
  String toString() => 'AppConfigLoaded';
}

class AppConfigInit extends AppConfigState<AppConfig> {
  AppConfigInit(AppConfig config) : super(config);

  @override
  String toString() => 'AppConfigInit';
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
