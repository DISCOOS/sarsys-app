import 'dart:collection';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends Bloc<DeviceCommand, DeviceState> {
  final DeviceService service;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Device> _devices = LinkedHashMap();

  DeviceBloc(this.service, this.incidentBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    incidentBloc.state.listen(_init);
    service.messages.listen((event) => dispatch(HandleMessage(event)));
  }

  void _init(IncidentState state) {
    if (state.isUnset() || state.isCreated() || state.isDeleted())
      dispatch(ClearDevices(_devices.keys.toList()));
    else if (state.isSelected()) _fetch(state.data.id);
  }

  @override
  DeviceState get initialState => DevicesEmpty();

  /// Check if [devices] is empty
  bool get isEmpty => devices.isEmpty;

  /// Get devices
  Map<String, Device> get devices => UnmodifiableMapView<String, Device>(_devices);

  /// Stream of device updates
  Stream<Device> get updates => state.where((state) => state.isUpdated()).map((state) => state.data);

  /// Fetch devices from [service]
  Future<List<Device>> fetch() async {
    if (incidentBloc.isUnset) {
      return Future.error(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'DeviceBloc.fetch()'",
      );
    }
    return _fetch(incidentBloc.current.id);
  }

  Future<List<Device>> _fetch(String id) async {
    var response = await service.fetch(id);
    if (response.is200) {
      dispatch(ClearDevices(_devices.keys.toList()));
      dispatch(LoadDevices(response.body));
      return UnmodifiableListView<Device>(response.body);
    }
    dispatch(RaiseDeviceError(response));
    return Future.error(response);
  }

  @override
  Stream<DeviceState> mapEventToState(DeviceCommand command) async* {
    if (command is LoadDevices) {
      yield _load(command.data);
    } else if (command is HandleMessage) {
      yield _process(command.data);
    } else if (command is ClearDevices) {
      yield _clear(command);
    } else if (command is RaiseDeviceError) {
      yield command.data;
    } else {
      yield DeviceError("Unsupported $command");
    }
  }

  DevicesLoaded _load(List<Device> devices) {
    _devices.addEntries(devices.map(
      (device) => MapEntry(device.id, device),
    ));
    return DevicesLoaded(_devices.keys.toList());
  }

  DeviceState _process(DeviceMessage event) {
    switch (event.type) {
      case DeviceMessageType.LocationChanged:
        var id = event.json['id'];
        if (_devices.containsKey(id)) {
          return DeviceUpdated(
            _devices.update(id, (device) => Device.fromJson(event.json)),
          );
        }
        break;
    }
    return DeviceError("Device message not recognized: $event");
  }

  DevicesCleared _clear(ClearDevices command) {
    List<Device> cleared = [];
    command.data.forEach((id) => {if (_devices.containsKey(id)) cleared.add(_devices.remove(id))});
    return DevicesCleared(cleared);
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
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

class HandleMessage extends DeviceCommand<DeviceMessage> {
  HandleMessage(DeviceMessage data) : super(data);

  @override
  String toString() => 'HandleMessage';
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
  isUpdated() => this is DeviceUpdated;
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

class DeviceUpdated extends DeviceState<Device> {
  DeviceUpdated(Device device) : super(device);

  @override
  String toString() => 'DeviceUpdated';
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
