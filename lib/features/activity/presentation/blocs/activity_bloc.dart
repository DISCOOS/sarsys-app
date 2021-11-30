

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/activity/domain/activity_profile.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityBloc extends BaseBloc<ActivityCommand, ActivityState, ActivityBlocError> {
  ActivityBloc({
    required BlocEventBus bus,
  }) : super(
          ActivityInitialized(ActivityProfile.PRIVATE),
          bus: bus,
        ) {
    assert(bus != null, "bus can not be null");
    subscribe<UserUnset>(_processAuth);
    subscribe<UserAuthenticated>(_processAuth);
    subscribe<DevicesLoaded>(_processDevice);
    subscribe<AppConfigUpdated>(_processConfig);
    subscribe<UserMobilized>(_processPersonnel);
    subscribe<PersonnelCreated>(_processPersonnel);
    subscribe<PersonnelUpdated>(_processPersonnel);
    subscribe<PersonnelDeleted>(_processPersonnel);
    subscribe<PersonnelsLoaded>(_processPersonnel);
    subscribe<PersonnelsUnloaded>(_processPersonnel);
  }

  /// Get stream of [ActivityProfile] changes
  Stream<ActivityProfile> get onChanged =>
      stream.where((event) => event.data is ActivityProfile).map((event) => event.data as ActivityProfile);

  /// Get trackable [Device]
  Device get trackable => _device;
  late Device _device;

  /// Get applied [AppConfig]
  AppConfig get applied => _config;
  late AppConfig _config;

  /// Check if bloc is ready
  bool get isReady => _isReady;
  var _isReady = false;

  /// Check if current profile allows tracking
  bool get isTrackable => _profile.isTrackable;

  /// Get current [ActivityProfile]
  ActivityProfile get profile => _profile;
  ActivityProfile _profile = ActivityProfile.PRIVATE;

  /// Get location service
  LocationService get service =>
      LocationService.exists ? LocationService() : LocationService(options: _profile.options);

  /// Get current [LocationOptions]
  LocationOptions? get options => service.options;

  UserRepository? _users;

  void _processAuth(BaseBloc bloc, UserState state) {
    _isReady = state.shouldLoad();
    _users = (bloc as UserBloc).repo;
  }

  void _processDevice(BaseBloc bloc, DeviceState state) async {
    if (state.isLoaded()) {
      final found = (bloc as DeviceBloc).app;
      if (found != _device) {
        dispatch(
          ConfigureLocationService(options, await isManual, _device = found!),
        );
      }
    }
  }

  void _processConfig<T extends BlocState>(Bloc bloc, T event) async {
    if (event.data is AppConfig) {
      _config = event.data;
      final next = _toOptions(
        _config,
        defaultAccuracy: null,
      );
      final manual = await isManual;
      if (options != next && manual) {
        dispatch(
          ConfigureLocationService(next, manual, _device),
        );
      }
    }
  }

  void _processPersonnel<T extends PersonnelState>(BaseBloc bloc, PersonnelState event) {
    final personnelBloc = (bloc as PersonnelBloc);
    final config = personnelBloc.operationBloc!.userBloc.config;
    if (event.data is Personnel) {
      final personnel = event.data as Personnel;
      if (personnelBloc.isUser(personnel.uuid)) {
        _onUserChanged(personnel.status, config);
      }
    } else {
      switch (event.runtimeType) {
        case PersonnelsLoaded:
          if (personnelBloc.isUserMobilized) {
            final user = personnelBloc.findUser().first!;
            _onUserChanged(user.status, config);
          }
          break;
        case PersonnelsUnloaded:
          _onUserChanged(PersonnelStatus.retired, config);
          break;
      }
    }
  }

  void _onUserChanged(PersonnelStatus? status, AppConfig config) async {
    var next;
    switch (status) {
      case PersonnelStatus.alerted:
        next = ActivityProfile.ALERTED;
        break;
      case PersonnelStatus.enroute:
        next = ActivityProfile.ENROUTE;
        break;
      case PersonnelStatus.onscene:
        next = ActivityProfile.ONSCENE;
        break;
      case PersonnelStatus.leaving:
        next = ActivityProfile.LEAVING;
        break;
      case PersonnelStatus.retired:
      default:
        next = ActivityProfile.PRIVATE;
        break;
    }
    await apply(
      profile: next,
      config: config,
      manual: await isManual,
    );
  }

  Future<bool> get isManual async {
    final prefs = await SharedPreferences.getInstance();
    final manual = prefs.getBool(LocationService.pref_location_manual);
    return manual ?? false;
  }

  Future<LocationOptions?> apply({
    bool? manual,
    AppConfig? config,
    ActivityProfile? profile,
  }) async {
    if (profile != null) {
      _profile = profile;
    }

    // Set manual flag if given
    if (manual != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(LocationService.pref_location_manual, manual);
    }
    manual = await isManual;

    // Get next options to apply
    final next = manual
        ? _toOptions(
            (_config = config!),
            defaultAccuracy: profile?.options.accuracy ?? options!.accuracy,
          )
        // Override current if
        : profile?.options ?? options;

    dispatch(
      (profile == null
          ? ConfigureLocationService(next, manual, _device)
          : ChangeActivityProfile(profile, manual, _device, next)) as ActivityCommand<dynamic, dynamic>,
    );

    return next;
  }

  @override
  ActivityBlocError createError(Object error, {StackTrace? stackTrace}) => ActivityBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  @override
  Stream<ActivityState> execute(ActivityCommand command) async* {
    if (command is ChangeActivityProfile) {
      yield await _change(command);
    } else if (command is ConfigureLocationService) {
      yield await _configure(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Future<ActivityState> _change(ChangeActivityProfile command) async {
    final options = await _apply(
      command.options,
      command.device,
    );
    return toOK(
      command,
      ActivityProfileChanged(
        command.data,
        command.manual,
        command.device,
        options,
      ),
      result: command.data,
    );
  }

  Future<ActivityState> _configure(ConfigureLocationService command) async {
    final options = await _apply(
      command.data,
      command.device,
    );
    return toOK(
      command,
      LocationServiceConfigured(
        _profile,
        command.manual,
        command.device,
        options,
      ),
      result: command.data,
    );
  }

  Future<LocationOptions?> _apply(LocationOptions? options, Device device) async {
    final isChanged = service.options != options ||
        service.token != _users?.token && _users?.isTokenValid == true ||
        service.duuid != device.uuid;

    if (_isReady && isChanged) {
      await service.configure(
        options: options,
        share: isTrackable,
        duuid: device.uuid,
        token: _users!.token,
      );
    }
    return service.options;
  }

  LocationOptions _toOptions(
    AppConfig config, {
    required LocationAccuracy? defaultAccuracy,
  }) =>
      LocationOptions(
        debug: config.locationDebug,
        accuracy: _toAccuracy(config, defaultAccuracy),
        locationAlways: config.locationAlways,
        locationWhenInUse: config.locationWhenInUse,
        activityRecognition: config.activityRecognition,
        timeInterval: config.locationFastestInterval,
        locationStoreLocally: config.locationStoreLocally,
        locationAllowSharing: config.locationAllowSharing,
        distanceFilter: config.locationSmallestDisplacement,
      );

  LocationAccuracy? _toAccuracy(AppConfig config, LocationAccuracy? defaultAccuracy) {
    final accuracy = config.toLocationAccuracy();
    if (accuracy == LocationAccuracy.automatic) {
      return defaultAccuracy;
    }
    return accuracy;
  }
}

/// ---------------------
/// Commands
/// ---------------------

abstract class ActivityCommand<S, T> extends BlocCommand<S, T> {
  ActivityCommand(S data, [props = const []]) : super(data, props);
}

class ChangeActivityProfile extends ActivityCommand<ActivityProfile, ActivityProfile> {
  ChangeActivityProfile(
    ActivityProfile profile,
    this.manual,
    this.device,
    this.options,
  ) : super(profile, [manual, device, options]);

  final bool manual;
  final Device device;
  final LocationOptions? options;

  @override
  String toString() => '$runtimeType {'
      'profile: $data, '
      'manual: $manual, '
      'device: $device, '
      'options: $options'
      '}';
}

class ConfigureLocationService extends ActivityCommand<LocationOptions?, LocationOptions> {
  ConfigureLocationService(
    LocationOptions? options,
    this.manual,
    this.device,
  ) : super(options);

  final bool manual;
  final Device device;

  @override
  String toString() => '$runtimeType {'
      'manual: $manual, '
      'options: $data, '
      'device: $device'
      '}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class ActivityState<T> extends BlocState<T> {
  ActivityState(
    T data, {
    StackTrace? stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isPrivate() => this is ActivityBlocError;
}

class ActivityInitialized extends ActivityState<ActivityProfile> {
  ActivityInitialized(ActivityProfile profile) : super(profile);

  @override
  String toString() => '$runtimeType';
}

class LocationServiceConfigured extends ActivityState<ActivityProfile> {
  LocationServiceConfigured(
    ActivityProfile profile,
    this.manual,
    this.device,
    this.options,
  ) : super(
          profile,
          props: [manual, options, device],
        );

  final bool manual;
  final Device device;
  final LocationOptions? options;

  @override
  String toString() => '$runtimeType, {'
      'profile: $data, '
      'manual: $manual, '
      'device: $device, '
      'options: $options}';
}

class ActivityProfileChanged extends ActivityState<ActivityProfile> {
  ActivityProfileChanged(
    ActivityProfile profile,
    this.manual,
    this.device,
    this.options,
  ) : super(
          profile,
          props: [manual, options, device],
        );

  final bool manual;
  final Device device;
  final LocationOptions? options;

  @override
  String toString() => '$runtimeType, {'
      'profile: $data, '
      'manual: $manual, '
      'device: $device, '
      'options: $options}';
}

/// ---------------------
/// Error states
/// ---------------------

class ActivityBlocError extends ActivityState<Object> {
  ActivityBlocError(
    Object error, {
    StackTrace? stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}
