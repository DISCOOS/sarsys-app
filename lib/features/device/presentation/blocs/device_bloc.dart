import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/activity/presentation/blocs/activity_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends StatefulBloc<DeviceCommand, DeviceState, DeviceBlocError, String, Device, DeviceService>
    with
        LoadableBloc<Iterable<Device>>,
        CreatableBloc<Device>,
        UpdatableBloc<Device>,
        DeletableBloc<Device>,
        UnloadableBloc<Iterable<Device>> {
  ///
  /// Default constructor
  ///
  DeviceBloc(this.repo, this.userBloc, BlocEventBus bus) : super(bus: bus) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");

    registerStreamSubscription(userBloc.listen(
      // Load and unload devices as needed
      _processUserState,
    ));

    // Notify when device state has changed
    forwardStateChanges(
      (t) => _NotifyDeviceStateChanged(t),
    );

    // Toggle device trackability
    bus.subscribe<ActivityProfileChanged>(
      _processActivityChange,
    );
  }

  void _processUserState(UserState state) {
    try {
      if (isOpen) {
        if (state.shouldLoad() && !repo.isReady) {
          dispatch(LoadDevices());
        } else if (state.shouldUnload(isOnline: isOnline) && repo.isReady) {
          dispatch(UnloadDevices());
        }
      }
    } catch (error, stackTrace) {
      BlocSupervisor.delegate.onError(
        this,
        error,
        stackTrace,
      );
      onError(error, stackTrace);
    }
  }

  StreamSubscription _locationChanged;

  void _processActivityChange<T extends BlocEvent>(Bloc bloc, T event) {
    if (event is ActivityProfileChanged) {
      final device = app;
      if (device != null && device.trackable != event.data.isTrackable) {
        dispatch(
          UpdateDevice(device.copyWith(trackable: event.data.isTrackable)),
        );

        // Forward device locations a-priori from backend
        _trackDevicePositionChangedApriori();
      }
    }
  }

  void _trackDevicePositionChangedApriori() {
    _locationChanged?.cancel();
    _locationChanged = LocationService().stream.listen((p) {
      final current = app;
      // Update device position for this app
      // a-priori of message from backend
      if (LocationService().isSharing && current.trackable) {
        final next = current.copyWith(position: p);
        service.publish(
          DeviceMessage.positionChanged(
            next.uuid,
            JsonUtils.diff(current, next),
          ),
        );
      }
    });
  }

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

  /// All repositories
  Iterable<StatefulRepository> get repos => [repo];

  /// Check if device is this application
  bool isThisApp(Device device) => userBloc.configBloc.config.udid == device.uuid;

  /// Check if device name should be updated
  bool _shouldSetUser(Device device, StorageStatus status) =>
      userBloc.isAuthenticated &&
      isThisApp(device) &&
      status != StorageStatus.deleted &&
      (device.name == null || device.alias == null || device.networkId != userBloc.userId);

  /// Get [OperationBloc]
  final UserBloc userBloc;

  /// Get [DeviceRepository]
  final DeviceRepository repo;

  /// Get all [Device]s
  Iterable<Device> get values => repo.values;

  /// Get [Device] count
  int count({List<DeviceStatus> exclude: const [DeviceStatus.unavailable]}) => repo.count(exclude: exclude);

  /// Get [Device] from [uuid]
  Device operator [](String uuid) => repo[uuid];

  /// Get [DeviceService]
  DeviceService get service => repo.service;

  /// Find device for this app
  Device get app {
    final uuid = userBloc.config?.udid;
    return uuid != null ? repo[uuid] : null;
  }

  @override
  DevicesEmpty get initialState => DevicesEmpty();

  /// Stream of changes on given device
  Stream<Device> onChanged(Device device, {bool skipPosition = false}) => where(
        (state) =>
            (state is DeviceUpdated &&
                state.isChanged() &&
                (!skipPosition || !state.isLocationChanged()) &&
                state.data.uuid == device.uuid) ||
            (state is DevicesLoaded && state.data.contains(device.uuid)),
      ).map((state) => state is DevicesLoaded ? repo[device.uuid] : state.data);

  /// Stream of changes on given device
  Stream<Device> onMoved(Device device) => where(
        (state) => (state.isLocationChanged() && state.data.uuid == device.uuid),
      ).map((state) => state.data);

  void _assertState() {
    if (!userBloc.isAuthenticated) {
      throw DeviceBlocError(
        "User not authenticated. "
        "Ensure that an User is authenticated before 'DeviceBloc.load()'",
      );
    }
  }

  void _assertData(Device data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Device $data have no uuid",
      );
    }
  }

  /// Fetch [map] from [service]
  @override
  Future<Iterable<Device>> load() async {
    _assertState();
    return dispatch<Iterable<Device>>(
      LoadDevices(),
    );
  }

  /// Create given [device]
  @override
  Future<Device> create(Device device) {
    _assertState();
    return dispatch<Device>(
      CreateDevice(device),
    );
  }

  /// Attach given [device] to [ouuid]
  Future<Device> attach(Device device) {
    _assertState();
    return update(
      device.copyWith(status: DeviceStatus.available),
    );
  }

  /// Detach given device from operation
  Future<Device> detach(Device device) {
    _assertState();
    return update(
      device.copyWith(status: DeviceStatus.unavailable),
    );
  }

  /// Update given [device]
  @override
  Future<Device> update(Device device) {
    _assertState();
    return dispatch<Device>(
      UpdateDevice(device),
    );
  }

  /// Delete given device
  @override
  Future<Device> delete(String uuid) {
    _assertState();
    return dispatch<Device>(
      DeleteDevice(repo[uuid]),
    );
  }

  /// Unload devices from local storage
  @override
  Future<Iterable<Device>> unload() {
    return dispatch<Iterable<Device>>(
      UnloadDevices(),
    );
  }

  @override
  Stream<DeviceState> execute(DeviceCommand command) async* {
    if (command is LoadDevices) {
      yield* _load(command);
    } else if (command is CreateDevice) {
      yield* _create(command);
    } else if (command is UpdateDevice) {
      yield* _update(command);
    } else if (command is DeleteDevice) {
      yield* _delete(command);
    } else if (command is _NotifyDeviceStateChanged) {
      yield await _notify(command);
    } else if (command is UnloadDevices) {
      yield await _unload(command);
    } else if (command is _NotifyBlocStateChange) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<DeviceState> _load(LoadDevices command) async* {
    // Fetch cached and handle
    // response from remote when ready
    final onRemote = Completer<Iterable<Device>>();
    var devices = await repo.load(
      onRemote: onRemote,
    );

    yield toOK(
      command,
      DevicesLoaded(repo.keys),
      result: devices,
    );

    // Update device for this app?
    if (app != null) {
      if (_shouldSetUser(app, repo.getState(app.uuid).status)) {
        final device = app.copyWith(
          network: 'sarsys',
          number: userBloc.user.phone,
          networkId: userBloc.user.userId,
          alias: await getDeviceModelName(),
        );
        dispatch(
          UpdateDevice(device),
        );
      }
    }

    // Notify when all states are remote
    onComplete(
      [onRemote.future],
      toState: (_) => DevicesLoaded(
        repo.keys,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<String> getDeviceModelName() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.model;
    }
    if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      return info.model;
    }
    return Platform.operatingSystem;
  }

  Stream<DeviceState> _create(CreateDevice command) async* {
    _assertData(command.data);
    var device = repo.apply(command.data);
    yield toOK(
      command,
      DeviceCreated(device),
      result: device,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(device.uuid)],
      toState: (_) => DeviceCreated(
        device,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<DeviceState> _update(UpdateDevice command) async* {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final device = repo.apply(command.data);
    yield toOK(
      command,
      DeviceUpdated(device, previous),
      result: device,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(device.uuid)],
      toState: (_) => DeviceUpdated(
        device,
        previous,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<DeviceState> _delete(DeleteDevice command) async* {
    _assertData(command.data);
    final device = repo.delete(command.data.uuid);
    yield toOK(
      command,
      DeviceDeleted(device),
      result: device,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(device.uuid, require: false)],
      toState: (_) => DeviceDeleted(
        device,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<DeviceState> _notify(_NotifyDeviceStateChanged command) async {
    _assertData(command.device);
    final device = command.device;

    if (command.isCreated) {
      return toOK(
        command,
        DeviceCreated(
          device,
          isRemote: command.isRemote,
        ),
        result: device,
      );
    }

    if (command.isUpdated) {
      return toOK(
        command,
        DeviceUpdated(
          device,
          command.previous,
          isRemote: command.isRemote,
        ),
        result: device,
      );
    }

    assert(command.isDeleted);

    return toOK(
      command,
      DeviceDeleted(
        device,
        isRemote: command.isRemote,
      ),
      result: device,
    );
  }

  Future<DeviceState> _unload(UnloadDevices command) async {
    final devices = await repo.close();
    return toOK(
      command,
      DevicesUnloaded(devices),
      result: devices,
    );
  }

  @override
  DeviceBlocError createError(Object error, {StackTrace stackTrace}) => DeviceBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}

/// ---------------------
/// Commands
/// ---------------------
abstract class DeviceCommand<S, T> extends BlocCommand<S, T> {
  DeviceCommand(S data, [props = const []]) : super(data, props);
}

class LoadDevices extends DeviceCommand<void, Iterable<Device>> {
  LoadDevices() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class CreateDevice extends DeviceCommand<Device, Device> {
  CreateDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class UpdateDevice extends DeviceCommand<Device, Device> {
  UpdateDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class DeleteDevice extends DeviceCommand<Device, Device> {
  DeleteDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class UnloadDevices extends DeviceCommand<void, Iterable<Device>> {
  UnloadDevices() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class _NotifyDeviceStateChanged extends DeviceCommand<StorageTransition<Device>, Device> {
  _NotifyDeviceStateChanged(
    StorageTransition<Device> transition,
  ) : super(transition);

  Device get device => data.to.value;
  Device get previous => data.from?.value;

  bool get isCreated => data.isCreated;
  bool get isUpdated => data.isChanged;
  bool get isDeleted => data.isDeleted;

  bool get isRemote => data.to?.isRemote == true;

  @override
  String toString() => '$runtimeType {previous: $data, next: $data}';
}

class _NotifyBlocStateChange extends DeviceCommand<DeviceState, Device> {
  _NotifyBlocStateChange(
    DeviceState state,
  ) : super(state);

  @override
  String toString() => '$runtimeType {state: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class DeviceState<T> extends PushableBlocEvent<T> {
  DeviceState(
    T data, {
    StackTrace stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data,
          props: [...props, isRemote],
          stackTrace: stackTrace,
          isRemote: isRemote,
        );

  bool isError() => this is DeviceBlocError;
  bool isEmpty() => this is DevicesEmpty;
  bool isLoaded() => this is DevicesLoaded;
  bool isCreated() => this is DeviceCreated;
  bool isUpdated() => this is DeviceUpdated;
  bool isDeleted() => this is DeviceDeleted;
  bool isUnloaded() => this is DevicesUnloaded;

  bool isAvailable() => (data is Device) ? (data as Device).status == DeviceStatus.available : false;
  bool isUnavailable() => (data is Device) ? (data as Device).status == DeviceStatus.unavailable : false;

  bool isStatusChanged() => false;
  bool isLocationChanged() => false;
}

class DevicesEmpty extends DeviceState<Null> {
  DevicesEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class DevicesLoaded extends DeviceState<List<String>> {
  DevicesLoaded(
    List<String> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {devices: $data, isRemote: $isRemote}';
}

class DeviceCreated extends DeviceState<Device> {
  DeviceCreated(
    Device device, {
    bool isRemote = false,
  }) : super(device, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {device: $data, isRemote: $isRemote}';
}

class DeviceUpdated extends DeviceState<Device> {
  DeviceUpdated(
    Device device,
    this.previous, {
    bool isRemote = false,
  }) : super(
          device,
          props: [previous],
          isRemote: isRemote,
        );
  final Device previous;

  bool isChanged() => data != previous;
  bool isStatusChanged() => data.status != previous?.status;
  bool isLocationChanged() => data.position != previous?.position;

  @override
  String toString() => '$runtimeType {device: $data, previous: $previous, isRemote: $isRemote}';
}

class DeviceDeleted extends DeviceState<Device> {
  DeviceDeleted(
    Device device, {
    bool isRemote = false,
  }) : super(device, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {device: $data, isRemote: $isRemote}';
}

class DevicesUnloaded extends DeviceState<Iterable<Device>> {
  DevicesUnloaded(Iterable<Device> devices) : super(devices);

  @override
  String toString() => '$runtimeType {devices: $data}';
}

/// ---------------------
/// Error states
/// ---------------------

class DeviceBlocError extends DeviceState<Object> {
  DeviceBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class DeviceBlocException implements Exception {
  DeviceBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final Object command;
  final DeviceState state;
  final StackTrace stackTrace;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
