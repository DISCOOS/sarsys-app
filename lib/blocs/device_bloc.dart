import 'dart:async';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/repositories/device_repository.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends Bloc<DeviceCommand, DeviceState> {
  DeviceBloc(this.repo, this.incidentBloc) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    _subscriptions
      ..add(incidentBloc.listen(
        _processIncidentEvent,
      ))
      ..add(service.messages.listen(
        _processDeviceMessage,
      ));
  }

  void _processIncidentEvent(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty) {
        if (state.shouldUnload(iuuid) && repo.isReady) {
          add(UnloadDevices(iuuid));
        } else if (state.isSelected()) {
          add(LoadDevices(state.data.uuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  void _processDeviceMessage(event) {
    if (_subscriptions.isNotEmpty) {
      try {
        add(_HandleMessage(event));
      } on Exception catch (error, stackTrace) {
        Catcher.reportCheckedError(
          error,
          stackTrace,
        );
      }
    }
  }

  /// Subscriptions released on [close]
  List<StreamSubscription> _subscriptions = [];

  /// Get [IncidentBloc]
  final IncidentBloc incidentBloc;

  /// Get [DeviceRepository]
  final DeviceRepository repo;

  /// Get [DeviceService]
  DeviceService get service => repo.service;

  /// [Incident] that manages given [devices]
  String get iuuid => repo.iuuid;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.iuuid == null;

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
    if (incidentBloc.isUnset) {
      throw DeviceError(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String uuid)' is called before 'DeviceBloc.load()'",
      );
    }
  }

  /// Fetch devices from [service]
  Future<List<Device>> load() async {
    _assertState();
    return _dispatch<List<Device>>(
      LoadDevices(iuuid ?? incidentBloc.selected.uuid),
    );
  }

  /// Create given device
  Future<Device> create(Device device) {
    _assertState();
    return _dispatch<Device>(
      CreateDevice(iuuid ?? incidentBloc.selected.uuid, device),
    );
  }

  /// Attach given device to given incident
  Future<Device> attach(Device device) {
    _assertState();
    return update(
      device.cloneWith(status: DeviceStatus.Unavailable),
    );
  }

  /// Detach given device from incident
  Future<Device> detach(Device device) {
    _assertState();
    return update(
      device.cloneWith(status: DeviceStatus.Available),
    );
  }

  /// Update given device
  Future<Device> update(Device device) {
    _assertState();
    return _dispatch<Device>(
      UpdateDevice(device),
    );
  }

  /// Detach given device
  Future<Device> delete(Device device) {
    _assertState();
    return _dispatch<Device>(
      DeleteDevice(device),
    );
  }

  /// Unload [devices] from local storage
  Future<List<Device>> unload() {
    _assertState();
    return _dispatch<List<Device>>(
      UnloadDevices(iuuid),
    );
  }

  @override
  Stream<DeviceState> mapEventToState(DeviceCommand command) async* {
    if (command is LoadDevices) {
      yield await _load(command);
    } else if (command is CreateDevice) {
      yield await _create(command);
    } else if (command is UpdateDevice) {
      yield await _update(command);
    } else if (command is DeleteDevice) {
      yield await _delete(command);
    } else if (command is _HandleMessage) {
      yield await _process(command.data);
    } else if (command is UnloadDevices) {
      yield await _unload(command);
    } else if (command is RaiseDeviceError) {
      yield _toError(
        command,
        command.data,
      );
    } else {
      yield _toError(
        command,
        DeviceError(
          "Unsupported $command",
          stackTrace: StackTrace.current,
        ),
      );
    }
  }

  Future<DeviceState> _load(LoadDevices command) async {
    var devices = await repo.load(command.data);
    return _toOK(
      command,
      DevicesLoaded(repo.keys),
      result: devices,
    );
  }

  Future<DeviceState> _create(CreateDevice command) async {
    var device = await repo.create(command.iuuid, command.data);
    return _toOK(
      command,
      DeviceCreated(device),
      result: device,
    );
  }

  Future<DeviceState> _update(UpdateDevice command) async {
    final device = await repo.update(command.data);
    return _toOK(
      command,
      DeviceUpdated(device),
      result: device,
    );
  }

  Future<DeviceState> _delete(DeleteDevice command) async {
    final device = await repo.delete(command.data.uuid);
    return _toOK(
      command,
      DeviceDeleted(device),
      result: device,
    );
  }

  Future<DeviceState> _unload(UnloadDevices command) async {
    final devices = await repo.unload();
    return _toOK(
      command,
      DevicesUnloaded(devices),
      result: devices,
    );
  }

  Future<DeviceState> _process(DeviceMessage event) async {
    switch (event.type) {
      case DeviceMessageType.LocationChanged:
        if (repo.containsKey(event.duuid)) {
          return DeviceUpdated(
            await repo.patch(Device.fromJson(event.json)),
          );
        }
        break;
    }
    throw DeviceBlocException(
      "Device message not recognized",
      state,
      command: event,
      stackTrace: StackTrace.current,
    );
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(DeviceCommand<Object, T> command) {
    add(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  DeviceState _toOK<T>(DeviceCommand event, DeviceState state, {T result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  DeviceState _toError(DeviceCommand event, Object error) {
    final object = error is DeviceError
        ? error
        : DeviceError(
            error,
            stackTrace: StackTrace.current,
          );
    event.callback.completeError(
      object,
      object.stackTrace ?? StackTrace.current,
    );
    return object;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscriptions.isNotEmpty) {
      add(RaiseDeviceError(DeviceError(
        error,
        stackTrace: stacktrace,
      )));
    } else {
      throw DeviceBlocException(
        error,
        state,
        stackTrace: stacktrace,
      );
    }
  }

  @override
  Future<void> close() async {
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
    super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class DeviceCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();

  DeviceCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadDevices extends DeviceCommand<String, List<Device>> {
  LoadDevices(String iuuid) : super(iuuid);

  @override
  String toString() => 'LoadDevices {iuuid: $data}';
}

class CreateDevice extends DeviceCommand<Device, Device> {
  final String iuuid;
  CreateDevice(this.iuuid, Device data) : super(data, [iuuid]);

  @override
  String toString() => 'CreateDevice {iuuid: $iuuid, devices: $data}';
}

class UpdateDevice extends DeviceCommand<Device, Device> {
  UpdateDevice(Device data) : super(data);

  @override
  String toString() => 'UpdateDevice {device: $data}';
}

class DeleteDevice extends DeviceCommand<Device, Device> {
  DeleteDevice(Device data) : super(data);

  @override
  String toString() => 'DetachDevice {device: $data}';
}

class _HandleMessage extends DeviceCommand<DeviceMessage, DeviceMessage> {
  _HandleMessage(DeviceMessage data) : super(data);

  @override
  String toString() => 'HandleMessage {message: $data}';
}

class UnloadDevices extends DeviceCommand<String, List<Device>> {
  UnloadDevices(String iuuid) : super(iuuid);

  @override
  String toString() => 'UnloadDevices {iuuid: $data}';
}

class RaiseDeviceError extends DeviceCommand<DeviceError, DeviceError> {
  RaiseDeviceError(DeviceError data) : super(data);

  @override
  String toString() => 'RaiseDeviceError {error: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class DeviceState<T> extends Equatable {
  final T data;

  DeviceState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is DevicesEmpty;
  isLoaded() => this is DevicesLoaded;
  isCreated() => this is DeviceCreated;
  isUpdated() => this is DeviceUpdated;
  isDeleted() => this is DeviceDeleted;
  isUnloaded() => this is DevicesUnloaded;
  isError() => this is DeviceError;
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
  DeviceUpdated(Device device) : super(device);

  @override
  String toString() => 'DeviceUpdated {device: $data}';
}

class DeviceDeleted extends DeviceState<Device> {
  DeviceDeleted(Device device) : super(device);

  @override
  String toString() => 'DeviceDetached {device: $data}';
}

class DevicesUnloaded extends DeviceState<List<Device>> {
  DevicesUnloaded(List<Device> devices) : super(devices);

  @override
  String toString() => 'DevicesUnloaded {devices: $data}';
}

/// ---------------------
/// Error states
/// ---------------------

class DeviceError extends DeviceState<Object> {
  final StackTrace stackTrace;
  DeviceError(Object error, {this.stackTrace}) : super(error, [stackTrace]);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class DeviceBlocException implements Exception {
  DeviceBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final DeviceState state;
  final StackTrace stackTrace;
  final Object command;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
