import 'dart:collection';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

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
    service.messages.listen((event) => dispatch(HandleMessage(event)));
  }

  void _init(IncidentState state) {
    if (state.isUnset() || state.isCreated() || state.isDeleted())
      dispatch(ClearTracks(_tracks.keys.toList()));
    else if (state.isSelected()) _fetch(state.data.id);
  }

  @override
  TrackingState get initialState => TracksEmpty();

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

  Future<UnmodifiableListView<Tracking>> _fetch(String id) async {
    dispatch(ClearTracks(_tracks.keys.toList()));
    var tracks = await service.fetch(id);
    dispatch(LoadTracks(tracks));
    return UnmodifiableListView<Tracking>(tracks);
  }

  /// Create tracking for given Unit
  TrackingBloc create(Unit unit, List<Device> devices) {
    dispatch(CreateTracking(unit.id, devices.map((device) => device.id).toList()));
    return this;
  }

  /// Update given tracking
  TrackingBloc update(Tracking tracking, {List<Device> devices, TrackingStatus status}) {
    dispatch(UpdateTracking(tracking.cloneWith(
      status: status,
      devices: devices == null ? tracking.devices : devices.map((device) => device.id).toList(),
    )));
    return this;
  }

  /// Transition tracking state to next legal state
  TrackingBloc transition(Tracking tracking) {
    switch (tracking.status) {
      case TrackingStatus.Created:
      case TrackingStatus.Paused:
      case TrackingStatus.Closed:
        update(tracking, status: TrackingStatus.Tracking);
        break;
      case TrackingStatus.Tracking:
        update(tracking, status: TrackingStatus.Paused);
        break;
      default:
        break;
    }
    return this;
  }

  @override
  Stream<TrackingState> mapEventToState(TrackingCommand command) async* {
    if (command is LoadTracks) {
      List<String> ids = _load(command.data);
      yield TracksLoaded(ids);
    } else if (command is CreateTracking) {
      Tracking data = await _create(command);
      yield TrackingCreated(data);
    } else if (command is UpdateTracking) {
      Tracking data = await _update(command);
      yield TrackingUpdated(data);
    } else if (command is DeleteTracking) {
      Tracking data = await _delete(command);
      yield TrackingDeleted(data);
    } else if (command is ClearTracks) {
      List<Tracking> tracks = _clear(command);
      yield TracksCleared(tracks);
    } else if (command is HandleMessage) {
      yield _process(command.data);
    } else if (command is RaiseTrackingError) {
      yield command.data;
    } else {
      yield TrackingError("Unsupported $command");
    }
  }

  List<String> _load(List<Tracking> tracks) {
    //TODO: Implement call to backend

    _tracks.addEntries(tracks.map(
      (tracking) => MapEntry(tracking.id, tracking),
    ));
    return _tracks.keys.toList();
  }

  Future<Tracking> _create(CreateTracking event) async {
    var tracking = await service.create(event.unitId, event.data);

    _tracks.putIfAbsent(
      tracking.id,
      () => tracking,
    );
    return Future.value(tracking);
  }

  TrackingState _process(TrackingMessage event) {
    switch (event.type) {
      case TrackingMessageType.TrackingChanged:
        var tracking = Tracking.fromJson(event.json);
        if (_tracks.containsKey(tracking.id)) {
          return TrackingUpdated(_tracks.update(tracking.id, (_) => tracking));
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

  Future<Tracking> _update(UpdateTracking event) async {
    var tracking = await service.update(event.data);

    _tracks.update(
      tracking.id,
      (_) => tracking,
      ifAbsent: () => tracking,
    );
    return Future.value(tracking);
  }

  Future<Tracking> _delete(DeleteTracking event) {
    //TODO: Implement call to backend

    if (_tracks.remove(event.data.id) == null) {
      throw "Failed to delete tracking ${event.data.id}";
    }
    return Future.value(event.data);
  }

  List<Tracking> _clear(ClearTracks command) {
    List<Tracking> cleared = [];
    command.data.forEach((id) => {if (_tracks.containsKey(id)) cleared.add(_tracks.remove(id))});
    return cleared;
  }

  @override
  void onEvent(TrackingCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<TrackingCommand, TrackingState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseTrackingError(TrackingError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<T> extends Equatable {
  final T data;

  TrackingCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadTracks extends TrackingCommand<List<Tracking>> {
  LoadTracks(List<Tracking> data) : super(data);

  @override
  String toString() => 'LoadTracks';
}

class CreateTracking extends TrackingCommand<List<String>> {
  final String unitId;
  CreateTracking(this.unitId, List<String> devices) : super(devices);

  @override
  String toString() => 'CreateTracking';
}

class UpdateTracking extends TrackingCommand<Tracking> {
  UpdateTracking(Tracking data) : super(data);

  @override
  String toString() => 'UpdateTracking';
}

class HandleMessage extends TrackingCommand<TrackingMessage> {
  HandleMessage(TrackingMessage data) : super(data);

  @override
  String toString() => 'HandleMessage';
}

class DeleteTracking extends TrackingCommand<Tracking> {
  DeleteTracking(Tracking data) : super(data);

  @override
  String toString() => 'DeleteTracking';
}

class ClearTracks extends TrackingCommand<List<String>> {
  ClearTracks(List<String> data) : super(data);

  @override
  String toString() => 'ClearTracks';
}

class RaiseTrackingError extends TrackingCommand<TrackingError> {
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

  isEmpty() => this is TracksEmpty;
  isLoaded() => this is TracksLoaded;
  isCreated() => this is TrackingCreated;
  isUpdated() => this is TrackingUpdated;
  isDeleted() => this is TrackingDeleted;
  isCleared() => this is TracksCleared;
  isException() => this is TrackingException;
  isError() => this is TrackingError;
}

class TracksEmpty extends TrackingState<Null> {
  TracksEmpty() : super(null);

  @override
  String toString() => 'TracksEmpty';
}

class TracksLoaded extends TrackingState<List<String>> {
  TracksLoaded(List<String> data) : super(data);

  @override
  String toString() => 'TracksLoaded';
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

class TracksCleared extends TrackingState<List<Tracking>> {
  TracksCleared(List<Tracking> tracks) : super(tracks);

  @override
  String toString() => 'TracksCleared';
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
