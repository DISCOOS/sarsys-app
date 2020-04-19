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
import 'package:flutter/foundation.dart';

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends Bloc<DeviceCommand, DeviceState> {
  final DeviceRepository repo;
  final IncidentBloc incidentBloc;

  DeviceService get service => repo.service;

  String get iuuid => incidentBloc.selected.uuid;

  List<StreamSubscription> _subscriptions = [];

  DeviceBloc(this.repo, this.incidentBloc) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    _subscriptions
      ..add(incidentBloc.listen(
        _init,
      ))
      ..add(service.messages.listen(
        _handle,
      ));
  }

  void _init(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty) {
        // Clear out current tracking upon states given below
        if (state.isUnset() ||
            state.isCreated() ||
            state.isDeleted() ||
            (state.isUpdated() &&
                [
                  IncidentStatus.Cancelled,
                  IncidentStatus.Resolved,
                ].contains((state as IncidentUpdated).data.status))) {
          //
          // TODO: Mark as internal event, no message from devices service expected
          //
          add(UnloadDevices(repo.iuuid));
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

  void _handle(event) {
    try {
      add(_HandleMessage(event));
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  @override
  DeviceState get initialState => DevicesEmpty();

  /// Stream of changes on given device
  Stream<Device> changes(Device device) => where(
        (state) =>
            (state is DeviceUpdated && state.data.id == device.id) ||
            (state is DevicesLoaded && state.data.contains(device.id)),
      ).map((state) => state is DevicesLoaded ? repo[device.id] : state.data);

  /// Get devices
  Map<String, Device> get devices => repo.map;

  /// Stream of device updates
  Stream<Device> get updates => where((state) => state.isUpdated()).map((state) => state.data);

  void _assertState() {
    if (incidentBloc.isUnset) {
      throw DeviceError(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'DeviceBloc.load()'",
      );
    }
  }

  /// Fetch devices from [service]
  Future<List<Device>> load() async {
    _assertState();
    return _dispatch<List<Device>>(
      LoadDevices(iuuid),
    );
  }

  /// Create given device
  Future<Device> create(Device device) {
    _assertState();
    return _dispatch<Device>(
      CreateDevice(iuuid, device),
    );
  }

  /// Attach given device from incident
  Future<Device> attach(Device device) {
    _assertState();
    return update(
      device.cloneWith(status: DeviceStatus.Attached),
    );
  }

  /// Detach given device from incident
  Future<Device> detach(Device device) {
    _assertState();
    return update(
      device.cloneWith(status: DeviceStatus.Detached),
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
    return _dispatch<void>(
      DeleteDevice(device),
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
      yield _toError(command, command.data);
    } else {
      yield _toError(
        command,
        DeviceError("Unsupported $command"),
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
    var device = await repo.create(iuuid, command.data);
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
    final device = await repo.delete(command.data);
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
    throw DeviceError("Device message not recognized: $event");
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
  DeviceState _toError(DeviceCommand event, Object response, {StackTrace stackTrace}) {
    final error = DeviceError(response, stackTrace: stackTrace);
    event.callback.completeError(error, stackTrace);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscriptions.isNotEmpty) {
      add(RaiseDeviceError(DeviceError(error, stackTrace: stacktrace)));
    } else {
      throw "Bad state: DeviceBloc is disposed. Unexpected ${DeviceError(error, stackTrace: stacktrace)}";
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

class UnloadDevices extends DeviceCommand<String, List<String>> {
  UnloadDevices(String iuuid) : super(iuuid);

  @override
  String toString() => 'UnloadDevices {iuuid: $data}';
}

class RaiseDeviceError extends DeviceCommand<DeviceError, DeviceError> {
  RaiseDeviceError(data) : super(data);

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
  isException() => this is DeviceException;
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
  String toString() => 'DevicesLoaded';
}

class DeviceCreated extends DeviceState<Device> {
  DeviceCreated(Device device) : super(device);

  @override
  String toString() => 'DeviceAttached';
}

class DeviceUpdated extends DeviceState<Device> {
  DeviceUpdated(Device device) : super(device);

  @override
  String toString() => 'DeviceUpdated';
}

class DeviceDeleted extends DeviceState<Device> {
  DeviceDeleted(Device device) : super(device);

  @override
  String toString() => 'DeviceDetached';
}

class DevicesUnloaded extends DeviceState<List<Device>> {
  DevicesUnloaded(List<Device> devices) : super(devices);

  @override
  String toString() => 'DevicesUnloaded';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class DeviceException extends DeviceState<Object> {
  final StackTrace stackTrace;
  DeviceException(Object error, {this.stackTrace}) : super(error, [stackTrace]);

  @override
  String toString() => 'DeviceException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class DeviceError extends DeviceException {
  final StackTrace stackTrace;
  DeviceError(Object error, {this.stackTrace}) : super(error, stackTrace: stackTrace);

  @override
  String toString() => 'DeviceError {data: $data}';
}
