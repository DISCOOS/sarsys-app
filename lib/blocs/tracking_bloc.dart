import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc extends Bloc<TrackingCommand, TrackingState> {
  final TrackingService service;
  final UnitBloc unitBloc;
  final DeviceBloc deviceBloc;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Tracking> _tracks = LinkedHashMap();

  TrackingBloc(this.service, this.incidentBloc, this.unitBloc, this.deviceBloc) {
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    assert(unitBloc != null, "unitBloc can not be null");
    assert(deviceBloc != null, "deviceBloc can not be null");
    incidentBloc.state.listen(_init);
    unitBloc.state.listen(_cleanup);
    service.messages.listen((event) => dispatch(HandleMessage(event)));
  }

  void _init(IncidentState state) {
    // Clear out current tracking upon states given below
    if (state.isUnset() ||
        state.isCreated() ||
        state.isDeleted() ||
        (state.isUpdated() &&
            [
              IncidentStatus.Cancelled,
              IncidentStatus.Resolved,
            ].contains((state as IncidentUpdated).data.status))) {
      dispatch(ClearTracking(_tracks.keys.toList()));
    } else if (state.isSelected()) {
      _fetch(state.data.id);
    }
  }

  void _cleanup(UnitState state) {
    if (state.isUpdated()) {
      final event = state as UnitUpdated;
      if (UnitStatus.Retired == event.data.status) {
        dispatch(HandleRemoved(event.data.tracking));
      }
    } else if (state.isDeleted()) {
      final event = state as UnitDeleted;
      dispatch(HandleRemoved(event.data.tracking));
    }
  }

  @override
  TrackingState get initialState => TrackingEmpty();

  /// Check if [tracks] is empty
  bool get isEmpty => _tracks.isEmpty;

  /// Get tracks
  Map<String, Tracking> get tracks => UnmodifiableMapView<String, Tracking>(_tracks);

  /// Get units being tracked
  Map<String, Unit> get units => UnmodifiableMapView(
        Map.fromEntries(
          unitBloc.units.entries.where((entry) => isTrackingUnit(entry.value)),
        ),
      );

  /// Test if unit is being tracked
  bool isTrackingUnit(Unit unit) => unit?.tracking != null && _tracks.containsKey(unit?.tracking);

  /// Get units being tracked
  Unit getUnitFromTrackingId(String id) =>
      unitBloc.units.values.firstWhere((unit) => isTrackingUnit(unit) && id == unit?.tracking);

  /// Get units for all tracked devices.
  Map<String, Set<Unit>> getUnitsByDeviceId() {
    final Map<String, Set<Unit>> map = {};
    units.values.forEach((unit) {
      getDevicesFromTrackingId(unit.tracking).forEach((device) {
        map.update(device.id, (set) {
          set.add(unit);
          return set;
        }, ifAbsent: () => {unit});
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Get devices being tracked by given id
  List<Device> getDevicesFromTrackingId(String id) => _tracks.containsKey(id)
      ? _tracks[id]
          .devices
          .where((id) => deviceBloc.devices.containsKey(id))
          .map((id) => deviceBloc.devices[id])
          .toList()
      : [];

  /// Get tracking for all tracked devices.
  Map<String, Set<Tracking>> getTrackingByDeviceId() {
    final Map<String, Set<Tracking>> map = {};
    _tracks.values.forEach((tracking) {
      getDevicesFromTrackingId(tracking.id).forEach((device) {
        map.update(device.id, (set) {
          set.add(tracking);
          return set;
        }, ifAbsent: () => {tracking});
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Test if unit is being tracked
  bool isTrackingDeviceById(String id) => getTrackingByDeviceId().containsKey(id);

  /// Fetch tracks from [service]
  Future<List<Tracking>> fetch() async {
    if (incidentBloc.isUnset) {
      return Future.error(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'TrackingBloc.fetch()'",
      );
    }
    return _fetch(incidentBloc.current.id);
  }

  Future<List<Tracking>> _fetch(String id) async {
    var response = await service.fetch(id);
    if (response.is200) {
      dispatch(ClearTracking(_tracks.keys.toList()));
      dispatch(LoadTracking(response.body));
      return UnmodifiableListView<Tracking>(response.body);
    }
    dispatch(RaiseTrackingError(response));
    return Future.error(response);
  }

  /// Create tracking for given Unit
  Future<Tracking> create(Unit unit, List<Device> devices) {
    return _dispatch<Tracking>(CreateTracking(unit, devices.map((device) => device.id).toList()));
  }

  /// Update given tracking
  Future<void> update(Tracking tracking, {List<Device> devices, TrackingStatus status}) {
    return _dispatch<void>(UpdateTracking(tracking.cloneWith(
      status: status,
      devices: devices == null ? tracking.devices : devices.map((device) => device.id).toList(),
    )));
  }

  /// Transition tracking state to next legal state
  Future<void> transition(Tracking tracking) {
    switch (tracking.status) {
      case TrackingStatus.Created:
      case TrackingStatus.Paused:
      case TrackingStatus.Closed:
        return update(tracking, status: TrackingStatus.Tracking);
        break;
      case TrackingStatus.Tracking:
        return update(tracking, status: TrackingStatus.Paused);
        break;
      default:
        break;
    }
    return Future.value(tracking);
  }

  @override
  Stream<TrackingState> mapEventToState(TrackingCommand command) async* {
    if (command is LoadTracking) {
      yield _load(command.data);
    } else if (command is CreateTracking) {
      yield await _create(command);
    } else if (command is UpdateTracking) {
      yield await _update(command);
    } else if (command is DeleteTracking) {
      yield await _delete(command);
    } else if (command is ClearTracking) {
      yield _clear(command);
    } else if (command is HandleMessage) {
      yield _process(command.data);
    } else if (command is HandleRemoved) {
      yield _remove(command);
    } else if (command is RaiseTrackingError) {
      yield command.data;
    } else {
      yield TrackingError("Unsupported $command");
    }
  }

  TrackingLoaded _load(List<Tracking> tracks) {
    _tracks.addEntries(tracks.map(
      (tracking) => MapEntry(tracking.id, tracking),
    ));
    return TrackingLoaded(_tracks.keys.toList());
  }

  Future<TrackingState> _create(CreateTracking event) async {
    var response = await service.create(event.unit.id, event.data);
    if (response.is200) {
      await unitBloc.update(
        event.unit.cloneWith(tracking: response.body.id),
      );
      final tracking = _tracks.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK(event, TrackingCreated(tracking), result: tracking);
    }
    return _toError(event, response);
  }

  TrackingState _remove(HandleRemoved command) {
    var state;
    final tracking = _tracks.remove(command.data);
    if (tracking != null) state = TrackingDeleted(tracking);
    return state;
  }

  TrackingState _process(TrackingMessage event) {
    switch (event.type) {
      case TrackingMessageType.TrackingChanged:
        // Only handle tracking in current incident
        if (event.incidentId == incidentBloc?.current?.id) {
          var tracking = Tracking.fromJson(event.json);
          // Update or add as new
          return TrackingUpdated(_tracks.update(tracking.id, (_) => tracking, ifAbsent: () => tracking));
        }
        break;
      case TrackingMessageType.LocationChanged:
        var id = event.json['id'];
        if (_tracks.containsKey(id)) {
          return TrackingUpdated(
            _tracks.update(id, (tracking) => tracking.cloneWith(location: Point.fromJson(event.json))),
          );
        }
        break;
    }
    return TrackingError("Tracking message not recognized: $event");
  }

  Future<TrackingState> _update(UpdateTracking event) async {
    var response = await service.update(event.data);
    if (response.is204) {
      _tracks.update(
        event.data.id,
        (_) => event.data,
        ifAbsent: () => event.data,
      );
      return _toOK(event, TrackingUpdated(event.data));
    }
    return _toError(event, response);
  }

  Future<TrackingState> _delete(DeleteTracking event) async {
    var response = await service.delete(event.data);
    if (response.is204) {
      if (_tracks.remove(event.data.id) == null) {
        return _toError(event, "Failed to delete tracking $event, not found locally");
      }
      return _toOK(event, TrackingDeleted(event.data));
    }
    return _toError(event, response);
  }

  TrackingCleared _clear(ClearTracking command) {
    List<Tracking> cleared = [];
    command.data.forEach((id) => {if (_tracks.containsKey(id)) cleared.add(_tracks.remove(id))});
    return TrackingCleared(cleared);
  }

// Dispatch and return future
  Future<R> _dispatch<R>(TrackingCommand<dynamic, R> command) {
    dispatch(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  Future<TrackingState> _toOK(TrackingCommand event, TrackingState state, {Tracking result}) async {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  Future<TrackingState> _toError(TrackingCommand event, Object response) async {
    final error = TrackingError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    dispatch(RaiseTrackingError(TrackingError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<T, R> extends Equatable {
  final T data;
  final Completer<R> callback = Completer();

  TrackingCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadTracking extends TrackingCommand<List<Tracking>, void> {
  LoadTracking(List<Tracking> data) : super(data);

  @override
  String toString() => 'LoadTracking';
}

class CreateTracking extends TrackingCommand<List<String>, Tracking> {
  final Unit unit;
  CreateTracking(this.unit, List<String> devices) : super(devices);

  @override
  String toString() => 'CreateTracking';
}

class UpdateTracking extends TrackingCommand<Tracking, void> {
  UpdateTracking(Tracking data) : super(data);

  @override
  String toString() => 'UpdateTracking';
}

class HandleMessage extends TrackingCommand<TrackingMessage, void> {
  HandleMessage(TrackingMessage data) : super(data);

  @override
  String toString() => 'HandleMessage';
}

class HandleRemoved extends TrackingCommand<String, void> {
  HandleRemoved(String id) : super(id);

  @override
  String toString() => 'HandleShortcut';
}

class DeleteTracking extends TrackingCommand<Tracking, void> {
  DeleteTracking(Tracking data) : super(data);

  @override
  String toString() => 'DeleteTracking';
}

class ClearTracking extends TrackingCommand<List<String>, void> {
  ClearTracking(List<String> data) : super(data);

  @override
  String toString() => 'ClearTracking';
}

class RaiseTrackingError extends TrackingCommand<TrackingError, void> {
  RaiseTrackingError(data) : super(data);

  @override
  String toString() => 'RaiseTrackingError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class TrackingState<T> extends Equatable {
  final T data;

  TrackingState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is TrackingEmpty;
  isLoaded() => this is TrackingLoaded;
  isCreated() => this is TrackingCreated;
  isUpdated() => this is TrackingUpdated;
  isDeleted() => this is TrackingDeleted;
  isCleared() => this is TrackingCleared;
  isException() => this is TrackingException;
  isError() => this is TrackingError;
}

class TrackingEmpty extends TrackingState<Null> {
  TrackingEmpty() : super(null);

  @override
  String toString() => 'TrackingEmpty';
}

class TrackingLoaded extends TrackingState<List<String>> {
  TrackingLoaded(List<String> data) : super(data);

  @override
  String toString() => 'TrackingLoaded';
}

class TrackingCreated extends TrackingState<Tracking> {
  TrackingCreated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingCreated';
}

class TrackingUpdated extends TrackingState<Tracking> {
  TrackingUpdated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingUpdated';
}

class TrackingDeleted extends TrackingState<Tracking> {
  TrackingDeleted(Tracking data) : super(data);

  @override
  String toString() => 'TrackingDeleted';
}

class TrackingCleared extends TrackingState<List<Tracking>> {
  TrackingCleared(List<Tracking> tracks) : super(tracks);

  @override
  String toString() => 'TrackingCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class TrackingException extends TrackingState<Object> {
  final StackTrace trace;
  TrackingException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'TrackingException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class TrackingError extends TrackingException {
  final StackTrace trace;
  TrackingError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'TrackingError {data: $data}';
}
