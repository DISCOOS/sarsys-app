import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends BaseBloc<DeviceCommand, DeviceState, DeviceBlocError>
    with
        LoadableBloc<Iterable<Device>>,
        CreatableBloc<Device>,
        UpdatableBloc<Device>,
        DeletableBloc<Device>,
        UnloadableBloc<Iterable<Device>> {
  ///
  /// Default constructor
  ///
  DeviceBloc(this.repo, this.userBloc) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");

    registerStreamSubscription(userBloc.listen(
      // Load and unload devices as needed
      _processUserState,
    ));

    registerStreamSubscription(repo.onChanged.listen(
      // Notify when repository state has changed
      _processRepoState,
    ));
  }

  void _processUserState(UserState state) {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad()) {
          dispatch(LoadDevices());
        } else if (state.shouldUnload() && repo.isReady) {
          dispatch(UnloadDevices());
        }
      }
    } on Exception catch (error, stackTrace) {
      BlocSupervisor.delegate.onError(this, error, stackTrace);
      onError(error, stackTrace);
    }
  }

  void _processRepoState(StorageTransition<Device> transition) {
    if (hasSubscriptions && transition.to.isRemote) {
      switch (transition.to.status) {
        case StorageStatus.created:
          break;
        case StorageStatus.updated:
          break;
        case StorageStatus.deleted:
          break;
      }
    }
  }

  /// Get [OperationBloc]
  final UserBloc userBloc;

  /// Get [DeviceRepository]
  final DeviceRepository repo;

  /// Get [DeviceService]
  DeviceService get service => repo.service;

  /// Get devices
  Map<String, Device> get devices => repo.map;

  @override
  DevicesEmpty get initialState => DevicesEmpty();

  /// Stream of changes on given device
  Stream<Device> onChanged(Device device) => where(
        (state) =>
            (state is DeviceUpdated && state.data.uuid == device.uuid) ||
            (state is DevicesLoaded && state.data.contains(device.uuid)),
      ).map((state) => state is DevicesLoaded ? repo[device.uuid] : state.data);

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
        "Device have no uuid",
      );
    }
  }

  /// Fetch [devices] from [service]
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

  /// Detach given device from incident
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

  /// Detach given device
  @override
  Future<Device> delete(String uuid) {
    _assertState();
    return dispatch<Device>(
      DeleteDevice(repo[uuid]),
    );
  }

  /// Unload [devices] from local storage
  @override
  Future<Iterable<Device>> unload() {
    _assertState();
    return dispatch<Iterable<Device>>(
      UnloadDevices(),
    );
  }

  @override
  Stream<DeviceState> execute(DeviceCommand command) async* {
    if (command is LoadDevices) {
      yield await _load(command);
    } else if (command is CreateDevice) {
      yield await _create(command);
    } else if (command is UpdateDevice) {
      yield await _update(command);
    } else if (command is DeleteDevice) {
      yield await _delete(command);
    } else if (command is UnloadDevices) {
      yield await _unload(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Future<DeviceState> _load(LoadDevices command) async {
    var devices = await repo.load();
    return toOK(
      command,
      DevicesLoaded(repo.keys),
      result: devices,
    );
  }

  Future<DeviceState> _create(CreateDevice command) async {
    _assertData(command.data);
    var device = await repo.create(command.data);
    return toOK(
      command,
      DeviceCreated(device),
      result: device,
    );
  }

  Future<DeviceState> _update(UpdateDevice command) async {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final device = await repo.update(command.data);
    return toOK(
      command,
      DeviceUpdated(device, previous),
      result: device,
    );
  }

  Future<DeviceState> _delete(DeleteDevice command) async {
    _assertData(command.data);
    final device = await repo.delete(command.data.uuid);
    return toOK(
      command,
      DeviceDeleted(device),
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
        stackTrace: StackTrace.current,
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

/// ---------------------
/// Normal States
/// ---------------------
abstract class DeviceState<T> extends BlocEvent<T> {
  DeviceState(
    T data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

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
  String toString() => 'DevicesEmpty';
}

class DevicesLoaded extends DeviceState<List<String>> {
  DevicesLoaded(List<String> data) : super(data);

  @override
  String toString() => 'DevicesLoaded {devices: $data}';
}

class DeviceCreated extends DeviceState<Device> {
  DeviceCreated(Device device) : super(device);

  @override
  String toString() => 'DeviceAttached {device: $data}';
}

class DeviceUpdated extends DeviceState<Device> {
  final Device previous;
  DeviceUpdated(Device device, this.previous) : super(device);

  bool isStatusChanged() => data.status != previous.status;
  bool isLocationChanged() => data.position != previous?.position;

  @override
  String toString() => 'DeviceUpdated {device: $data, previous: $previous}';
}

class DeviceDeleted extends DeviceState<Device> {
  DeviceDeleted(Device device) : super(device);

  @override
  String toString() => 'DeviceDetached {device: $data}';
}

class DevicesUnloaded extends DeviceState<Iterable<Device>> {
  DevicesUnloaded(Iterable<Device> devices) : super(devices);

  @override
  String toString() => 'DevicesUnloaded {devices: $data}';
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
