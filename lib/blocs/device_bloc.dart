import 'dart:collection';

import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends Bloc<DeviceCommand, DeviceState> {
  final DeviceService service;

  final LinkedHashMap<String, Device> _devices = LinkedHashMap();

  DeviceBloc(this.service);

  @override
  DeviceState get initialState => DevicesEmpty();

  /// Check if [devices] is empty
  bool get isEmpty => devices.isEmpty;

  /// Get devices
  List<Device> get devices => UnmodifiableListView<Device>(_devices.values);

  /// Initialize if empty
  DeviceBloc init(DeviceCallback onInit) {
    if (isEmpty) {
      fetch().then((_) => onInit(() {}));
    }
    return this;
  }

  /// Fetch devices from [service]
  Future<List<Device>> fetch() async {
    dispatch(ClearDevices(_devices.keys.toList()));
    var devices = await service.fetch();
    dispatch(LoadDevices(devices));
    return UnmodifiableListView<Device>(devices);
  }

  @override
  Stream<DeviceState> mapEventToState(DeviceCommand command) async* {
    if (command is LoadDevices) {
      List<String> ids = _load(command.data);
      yield DevicesLoaded(ids);
    } else if (command is ClearDevices) {
      List<Device> devices = _clear(command);
      yield DevicesCleared(devices);
    } else if (command is RaiseDeviceError) {
      yield command.data;
    } else {
      yield DeviceError("Unsupported $command");
    }
  }

  List<String> _load(List<Device> devices) {
    //TODO: Implement call to backend

    _devices.addEntries(devices.map(
      (device) => MapEntry(device.id, device),
    ));
    return _devices.keys.toList();
  }

  List<Device> _clear(ClearDevices command) {
    List<Device> cleared = [];
    command.data.forEach((id) => {if (_devices.containsKey(id)) cleared.add(_devices.remove(id))});
    return cleared;
  }

  @override
  void onEvent(DeviceCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<DeviceCommand, DeviceState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseDeviceError(DeviceError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class DeviceCommand<T> extends Equatable {
  final T data;

  DeviceCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadDevices extends DeviceCommand<List<Device>> {
  LoadDevices(List<Device> data) : super(data);

  @override
  String toString() => 'LoadDevices';
}

class ClearDevices extends DeviceCommand<List<String>> {
  ClearDevices(List<String> data) : super(data);

  @override
  String toString() => 'ClearDevices';
}

class RaiseDeviceError extends DeviceCommand<DeviceError> {
  RaiseDeviceError(data) : super(data);

  @override
  String toString() => 'RaiseDeviceError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class DeviceState<T> extends Equatable {
  final T data;

  DeviceState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is DevicesEmpty;
  isLoaded() => this is DevicesLoaded;
  isCleared() => this is DevicesCleared;
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

class DevicesCleared extends DeviceState<List<Device>> {
  DevicesCleared(List<Device> devices) : super(devices);

  @override
  String toString() => 'DevicesCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class DeviceException extends DeviceState<Object> {
  final StackTrace trace;
  DeviceException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'DeviceException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class DeviceError extends DeviceException {
  final StackTrace trace;
  DeviceError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'DeviceError {data: $data}';
}
