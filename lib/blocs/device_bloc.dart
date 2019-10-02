import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';

typedef void DeviceCallback(VoidCallback fn);

class DeviceBloc extends Bloc<DeviceCommand, DeviceState> {
  final DeviceService service;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Device> _devices = LinkedHashMap();

  List<StreamSubscription> _subscriptions = [];

  DeviceBloc(this.service, this.incidentBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    _subscriptions
      ..add(incidentBloc.state.listen(_init))
      ..add(service.messages.listen((event) => dispatch(HandleMessage(event))));
  }

  void _init(IncidentState state) {
    if (_subscriptions.isNotEmpty) {
      if (state.isUnset() || state.isCreated() || state.isDeleted())
        dispatch(ClearDevices(_devices.keys.toList()));
      else if (state.isSelected()) _fetch(state.data.id);
    }
  }

  @override
  DeviceState get initialState => DevicesEmpty();

  /// Stream of changes on given device
  Stream<Device> changes(Device device) => state
      .where(
        (state) =>
            (state is DeviceUpdated && state.data.id == device.id) ||
            (state is DevicesLoaded && state.data.contains(device.id)),
      )
      .map((state) => state is DevicesLoaded ? _devices[device.id] : state.data);

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
      return _dispatch(LoadDevices(response.body));
    }
    dispatch(RaiseDeviceError(response));
    return Future.error(response);
  }

  @override
  Stream<DeviceState> mapEventToState(DeviceCommand command) async* {
    if (command is LoadDevices) {
      yield _load(command);
    } else if (command is HandleMessage) {
      yield _process(command.data);
    } else if (command is ClearDevices) {
      yield _clear(command);
    } else if (command is RaiseDeviceError) {
      yield _toError(command, command.data);
    } else {
      yield _toError(command, DeviceError("Unsupported $command"));
    }
  }

  DevicesLoaded _load(LoadDevices command) {
    _devices.addEntries(command.data.map(
      (device) => MapEntry(device.id, device),
    ));
    return _toOK(command, DevicesLoaded(_devices.keys.toList()));
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
    return _toOK(command, DevicesCleared(cleared));
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(DeviceCommand<T> command) {
    dispatch(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  DeviceState _toOK(DeviceCommand event, DeviceState state, {Device result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  DeviceState _toError(DeviceCommand event, Object response) {
    final error = DeviceError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscriptions.isNotEmpty) {
      dispatch(RaiseDeviceError(DeviceError(error, trace: stacktrace)));
    } else {
      throw "Bad state: DeviceBloc is disposed. Unexpected ${DeviceError(error, trace: stacktrace)}";
    }
  }

  @override
  void dispose() {
    super.dispose();
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class DeviceCommand<T> extends Equatable {
  final T data;
  final Completer<T> callback = Completer();

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
