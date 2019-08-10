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

  /// Fetch config from [service]
  Future<AppConfig> fetch() async {
    var response = await service.fetch();
    if (response.is200) {
      dispatch(FetchAppConfig(response.body));
      return response.body;
    }
    dispatch(RaiseAppConfigError(response));
    return Future.error(response);
  }

  /// Update given settings
  Future<AppConfig> update({
    bool onboarding,
    String district,
    String department,
    String talkGroups,
    bool locationWhenInUse,
  }) async {
    if (!isReady) return Future.error("AppConfig not ready");
    final config = this.config.copyWith(
          onboarding: onboarding,
          district: district,
          department: department,
          talkGroups: talkGroups,
          locationWhenInUse: locationWhenInUse,
        );
    var response = await service.save(config);
    if (response.is204) {
      dispatch(UpdateAppConfig(config));
      return config;
    }
    dispatch(RaiseAppConfigError(response));
    return Future.error(response);
  }

  @override
  Stream<AppConfigState> mapEventToState(AppConfigCommand command) async* {
    if (command is FetchAppConfig || command is UpdateAppConfig) {
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
