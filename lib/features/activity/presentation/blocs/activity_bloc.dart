import 'package:SarSys/core/data/services/location/location_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/activity/domain/activity_profile.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

class ActivityBloc extends BaseBloc<ActivityCommand, ActivityState, ActivityBlocError> {
  ActivityBloc({@required BlocEventBus bus}) : super(bus: bus) {
    assert(bus != null, "bus can not be null");
    bus.subscribe<AppConfigUpdated>(_processConfig);
    bus.subscribe<PersonnelsLoaded>(_processPersonnel);
    bus.subscribe<PersonnelCreated>(_processPersonnel);
    bus.subscribe<PersonnelUpdated>(_processPersonnel);
    bus.subscribe<PersonnelsUnloaded>(_processPersonnel);
  }

  Stream<ActivityProfile> get onChanged =>
      where((event) => event.data is ActivityProfile).map((event) => event.data as ActivityProfile);

  LocationOptions _toOptions(
    AppConfig config, {
    @required bool debug,
    @required LocationAccuracy defaultAccuracy,
  }) =>
      LocationOptions(
        debug: debug,
        accuracy: _toAccuracy(config, defaultAccuracy),
        locationAlways: config.locationAlways ?? false,
        locationWhenInUse: config.locationWhenInUse ?? false,
        activityRecognition: config.activityRecognition ?? false,
        timeInterval: config.locationFastestInterval ?? Defaults.locationFastestInterval,
        locationStoreLocally: config.locationStoreLocally ?? Defaults.locationStoreLocally,
        locationAllowSharing: config.locationAllowSharing ?? Defaults.locationAllowSharing,
        distanceFilter: config.locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement,
      );

  LocationAccuracy _toAccuracy(AppConfig config, LocationAccuracy defaultAccuracy) {
    final accuracy = config.toLocationAccuracy();
    if (accuracy == LocationAccuracy.automatic) {
      return defaultAccuracy;
    }
    return accuracy;
  }

  bool _isConfigChanged(AppConfig config, LocationOptions options) {
    return options?.locationAlways != (config.locationAlways ?? options.locationAlways) ||
        options?.accuracy != config.toLocationAccuracy(defaultValue: options.accuracy) ||
        options?.timeInterval != (config.locationFastestInterval ?? options.timeInterval) ||
        options?.locationWhenInUse != (config.locationWhenInUse ?? options.locationWhenInUse) ||
        options?.distanceFilter != (config.locationSmallestDisplacement ?? options.distanceFilter) ||
        options?.activityRecognition != (config.activityRecognition ?? options.activityRecognition) ||
        options?.locationStoreLocally != (config.locationStoreLocally ?? options.locationStoreLocally) ||
        options?.locationAllowSharing != (config.locationAllowSharing ?? options.locationAllowSharing);
  }

  /// Get current [ActivityProfile]
  ActivityProfile get profile => _profile;
  ActivityProfile _profile = ActivityProfile.PRIVATE;

  @override
  ActivityInitialized get initialState => ActivityInitialized(ActivityProfile.PRIVATE);

  @override
  Stream<ActivityState> execute(ActivityCommand command) async* {
    if (command is ChangeActivityProfile) {
      yield await _change(command);
    } else {
      yield toUnsupported(command);
    }
  }

  @override
  ActivityBlocError createError(Object error, {StackTrace stackTrace}) => ActivityBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  Future<ActivityState> _change(ChangeActivityProfile command) async {
    _profile = command.data;
    await LocationService().configure(
      options: command.data.options,
    );
    return toOK(
      command,
      ActivityProfileChanged(command.data),
      result: command.data,
    );
  }

  bool get isTrackable => _profile?.isTrackable ?? false;

  void _processConfig<T extends BlocEvent>(Bloc bloc, T event) {
    if (event.data is AppConfig) {
      final config = event.data as AppConfig;
      _apply(
        config,
        LocationService().options,
      );
    }
  }

  void _apply(AppConfig config, LocationOptions options) {
    final service = LocationService();
    if (_isConfigChanged(config, options)) {
      service.configure(
        options: _toOptions(
          config,
          defaultAccuracy: options.accuracy,
          debug: service.options?.debug ?? kDebugMode,
        ),
        share: isTrackable,
      );
    }
  }

  void _processPersonnel<T extends BlocEvent>(Bloc bloc, T event) {
    final config = (bloc as PersonnelBloc).operationBloc.userBloc.config;
    if (event is PersonnelsLoaded) {
      final working = (bloc as PersonnelBloc).findUser();
      if (working.isNotEmpty) {
        _onUser(working.first.status, config);
      } else {
        _onUser(PersonnelStatus.retired, config);
      }
    } else if (event.data is Personnel) {
      final personnel = event.data as Personnel;
      if ((bloc as PersonnelBloc).isUser(personnel.uuid)) {
        _onUser(personnel.status, config);
      }
    } else if (event is PersonnelsUnloaded) {
      _onUser(PersonnelStatus.retired, config);
    }
  }

  void _onUser(PersonnelStatus status, AppConfig config) {
    switch (status) {
      case PersonnelStatus.alerted:
        _profile = ActivityProfile.ALERTED;
        break;
      case PersonnelStatus.enroute:
        _profile = ActivityProfile.ENROUTE;
        break;
      case PersonnelStatus.onscene:
        _profile = ActivityProfile.ONSCENE;
        break;
      case PersonnelStatus.leaving:
        _profile = ActivityProfile.LEAVING;
        break;
      case PersonnelStatus.retired:
      default:
        _profile = ActivityProfile.PRIVATE;
        break;
    }
    _apply(
      config,
      _profile.options,
    );
    dispatch(
      ChangeActivityProfile(_profile),
    );
  }
}

/// ---------------------
/// Commands
/// ---------------------

abstract class ActivityCommand<S, T> extends BlocCommand<S, T> {
  ActivityCommand(S data, [props = const []]) : super(data, props);
}

class ChangeActivityProfile extends ActivityCommand<ActivityProfile, ActivityProfile> {
  ChangeActivityProfile(ActivityProfile data) : super(data);
  @override
  String toString() => '$runtimeType {profile: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class ActivityState<T> extends BlocEvent<T> {
  ActivityState(
    T data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isPrivate() => this is ActivityBlocError;
}

class ActivityInitialized extends ActivityState<ActivityProfile> {
  ActivityInitialized(ActivityProfile profile) : super(profile);

  @override
  String toString() => '$runtimeType';
}

class ActivityProfileChanged extends ActivityState<ActivityProfile> {
  ActivityProfileChanged(ActivityProfile profile) : super(profile);

  @override
  String toString() => '$runtimeType, {profile: $data}';
}

/// ---------------------
/// Error states
/// ---------------------

class ActivityBlocError extends ActivityState<Object> {
  ActivityBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}
