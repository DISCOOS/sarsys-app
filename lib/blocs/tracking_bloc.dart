import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc extends Bloc<TrackingCommand, TrackingState> {
  final TrackingService service;
  final UnitBloc unitBloc;
  final PersonnelBloc personnelBloc;
  final DeviceBloc deviceBloc;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Tracking> _tracking = LinkedHashMap();

  List<StreamSubscription> _subscriptions = [];

  TrackingBloc({
    this.service,
    this.incidentBloc,
    this.deviceBloc,
    this.unitBloc,
    this.personnelBloc,
  }) {
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    assert(unitBloc != null, "unitBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    assert(deviceBloc != null, "deviceBloc can not be null");
    _subscriptions
      ..add(incidentBloc.state.listen(_init))
      // Manages tracking state for units
      ..add(unitBloc.state.listen(_handleUnit))
      // Manages tracking state for devices
      ..add(deviceBloc.state.listen(_handleDevice))
      // Manages tracking state for personnel
      ..add(personnelBloc.state.listen(_handlePersonnel))
      // Process tracking messages
      ..add(service.messages.listen((event) => dispatch(_HandleMessage(event))));
  }

  void _init(IncidentState state) {
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
        // TODO: Mark as internal event, no message from tracking service expected
        dispatch(ClearTracking(_tracking.keys.toList()));
      } else if (state.isSelected()) {
        _fetch(state.data.id);
      }
    }
  }

  void _handleDevice(DeviceState state) {
    if (state.isUpdated()) {
      final device = (state as DeviceUpdated).data;
      if (DeviceStatus.Detached == device.status) {
        final tracking = find(device);
        // Remove device from active list of tracked devices? This will not impact history!
        if (tracking?.devices?.contains(device.id) == true) {
          // TODO: Move to tracking service and convert to internal TrackingMessage
          dispatch(
            UpdateTracking(
              tracking.cloneWith(
                devices: List.from(tracking.devices)..remove(device.id),
              ),
            ),
          );
        }
      }
    } else if (state.isDeleted()) {
      final device = (state as DeviceDeleted).data;
      final tracking = find(device);
      // Delete device data from tracking? This will impact history!
      if (tracking != null && tracking.devices.contains(device.id)) {
        // TODO: Move to tracking service and convert to internal TrackingMessage
        // TODO: Recalculate history, point, effort, distance and speed after device is removed
        dispatch(
          UpdateTracking(
            tracking.cloneWith(
              devices: List.from(tracking.devices)..remove(device.id),
              tracks: Map.from(tracking.tracks)..remove(device.id),
            ),
          ),
        );
      }
    }
  }

  void _handleUnit(UnitState state) {
    if (state.isUpdated()) {
      final event = state as UnitUpdated;
      final tracking = _tracking[event.data.tracking];
      // Close tracking?
      if (tracking != null) {
        if (UnitStatus.Retired == event.data.status) {
          // TODO: Move to tracking service and convert to internal TrackingMessage
          dispatch(
            UpdateTracking(
              tracking.cloneWith(
                status: TrackingStatus.Closed,
                devices: [],
              ),
            ),
          );
        } else if (TrackingStatus.Closed == tracking.status) {
          // TODO: Move to tracking service and convert to internal TrackingMessage
          dispatch(
            UpdateTracking(
              tracking.cloneWith(
                status: TrackingStatus.Tracking,
              ),
            ),
          );
        }
      }
    } else if (state.isDeleted()) {
      final event = state as UnitDeleted;
      final tracking = _tracking[event.data.tracking];
      // TODO: Move to tracking service and convert to internal TrackingMessage
      if (tracking != null) dispatch(DeleteTracking(tracking));
    }
  }

  void _handlePersonnel(PersonnelState state) {
    if (state.isUpdated()) {
      final event = state as PersonnelUpdated;
      final tracking = _tracking[event.data.tracking];
      // Close tracking?
      if (tracking != null) {
        if (PersonnelStatus.Retired == event.data.status) {
          // TODO: Move to tracking service and convert to internal TrackingMessage
          dispatch(
            UpdateTracking(
              tracking.cloneWith(
                status: TrackingStatus.Closed,
                devices: [],
              ),
            ),
          );
        } else if (TrackingStatus.Closed == tracking.status) {
          // TODO: Move to tracking service and convert to internal TrackingMessage
          dispatch(
            UpdateTracking(
              tracking.cloneWith(
                status: TrackingStatus.Tracking,
              ),
            ),
          );
        }
      }
    } else if (state.isDeleted()) {
      final event = state as PersonnelDeleted;
      final tracking = _tracking[event.data.tracking];
      // TODO: Move to tracking service and convert to internal TrackingMessage
      if (tracking != null) dispatch(DeleteTracking(tracking));
    }
  }

  @override
  TrackingState get initialState => TrackingEmpty();

  /// Stream of tracking changes for test
  Stream<Tracking> changes(String tracking) => state
      .where(
        (state) =>
            (state is TrackingUpdated && state.data.id == tracking) ||
            (state is TrackingLoaded && state.data.contains(tracking)),
      )
      .map((state) => state is TrackingLoaded ? _tracking[tracking] : state.data);

  /// Check if [tracking] is empty
  bool get isEmpty => _tracking.isEmpty;

  /// Get all tracking objects
  Map<String, Tracking> get tracking => UnmodifiableMapView<String, Tracking>(_tracking);

  /// Get units being tracked
  Entities<Unit> get units => Entities<Unit>(
        bloc: this,
        data: this.unitBloc.units,
        asId: (unit) => unit?.tracking,
      );

  /// Get personnel being tracked
  Entities<Personnel> get personnel => Entities<Personnel>(
        bloc: this,
        data: this.personnelBloc.personnel,
        asId: (personnel) => personnel?.tracking,
      );

  /// Get aggregates being tracked
  Entities<Tracking> get aggregates => Entities<Tracking>(
        bloc: this,
        data: Map.fromEntries(
          _tracking.values.where((tracking) => tracking.aggregates.isNotEmpty).fold(
            {},
            (map, tracking) => map.toList()
              ..addAll(
                tracking.aggregates.map(
                  (id) => MapEntry(id, _tracking[id]),
                ),
              ),
          ),
        ),
        asId: (aggregate) => aggregate?.id,
      );

  /// Test if device is being tracked
  bool contains(
    Device device, {
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      find(device) != null;

  /// Find tracking from given device. Returns null if not found.
  Tracking find(
    Device device, {
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      _tracking.entries
          .where((entry) => !exclude.contains(entry.value.status))
          .firstWhere((entry) => entry.value.devices.contains(device.id), orElse: () => null)
          ?.value;

  /// Get devices being tracked by given tracking id
  List<Device> devices(
    String id, {
    List<TrackingStatus> exclude = const [TrackingStatus.Closed],
  }) =>
      _tracking.containsKey(id) && !exclude.contains(_tracking[id].status)
          ? _tracking[id]
              .devices
              .where((id) => deviceBloc.devices.containsKey(id))
              .map((id) => deviceBloc.devices[id])
              .toList()
          : [];

  /// Get tracking for all tracked devices as a map from device id to all [Tracking] instances tracking the device
  /// TODO: Implement validation of restriction "a device can only be tracked by one tracking instance"
  Map<String, Set<Tracking>> asDeviceIds() {
    final Map<String, Set<Tracking>> map = {};
    _tracking.values.forEach((tracking) {
      devices(tracking.id).forEach((device) {
        map.update(device.id, (set) {
          set.add(tracking);
          return set;
        }, ifAbsent: () => {tracking});
      });
    });
    return UnmodifiableMapView(map);
  }

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
      dispatch(ClearTracking(_tracking.keys.toList()));
      dispatch(LoadTracking(response.body));
      return UnmodifiableListView<Tracking>(response.body);
    }
    dispatch(RaiseTrackingError(response));
    return Future.error(response);
  }

  /// Create tracking for given Unit
  Future<Tracking> trackUnit(
    Unit unit, {
    List<Device> devices,
    List<Personnel> personnel,
  }) {
    return _dispatch<Tracking>(TrackUnit(
      unit,
      devices: devices.map((device) => device.id).toList(),
      personnel: personnel,
    ));
  }

  /// Create tracking for given personnel
  Future<Tracking> trackPersonnel(Personnel personnel, {List<Device> devices}) {
    return _dispatch<Tracking>(TrackPersonnel(
      personnel,
      devices: devices.map((device) => device.id).toList(),
    ));
  }

  /// Update given tracking
  Future<Tracking> update(
    Tracking tracking, {
    List<Device> devices,
    List<Personnel> personnel,
    Point point,
    TrackingStatus status,
    bool append = false,
  }) {
    // Only use parameter 'devices' or 'personnel' if not null, otherwise use existing values
    var deviceIds = (devices?.map((d) => d.id) ?? tracking.devices)?.toList();
    var aggregateIds = (personnel?.map((p) => p.tracking)?.where((id) => id != null) ?? tracking.aggregates)?.toList();

    // Append unique ids
    if (append) {
      deviceIds = Set<String>.from(deviceIds..addAll(tracking.devices)).toList();
      aggregateIds = Set<String>.from(aggregateIds..addAll(tracking.aggregates)).toList();
    }

    return _dispatch<Tracking>(UpdateTracking(tracking.cloneWith(
      status: status,
      point: point == null ? tracking.point : point,
      devices: deviceIds,
      aggregates: aggregateIds,
    )));
  }

  /// Transition tracking state to next legal state
  Future<Tracking> transition(Tracking tracking) {
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
    } else if (command is TrackUnit) {
      yield await _trackUnit(command);
    } else if (command is TrackPersonnel) {
      yield await _trackPersonnel(command);
    } else if (command is UpdateTracking) {
      yield await _update(command);
    } else if (command is DeleteTracking) {
      yield await _delete(command);
    } else if (command is ClearTracking) {
      yield _clear(command);
    } else if (command is _HandleMessage) {
      yield _process(command.data);
    } else if (command is RaiseTrackingError) {
      yield command.data;
    } else {
      yield TrackingError("Unsupported $command");
    }
  }

  TrackingLoaded _load(List<Tracking> tracks) {
    _tracking.addEntries(tracks.map(
      (tracking) => MapEntry(tracking.id, tracking),
    ));
    return TrackingLoaded(_tracking.keys.toList());
  }

  Future<TrackingState> _trackUnit(TrackUnit event) async {
    var response = await service.create(
      incidentBloc.current.id,
      devices: event.data,
      aggregates: event.personnel.map((p) => p.tracking).where((id) => id != null).toList(),
    );
    if (response.is200) {
      await unitBloc.update(
        event.unit.cloneWith(tracking: response.body.id),
      );
      final tracking = _tracking.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK(event, TrackingCreated(tracking), result: tracking);
    }
    return _toError(event, response);
  }

  Future<TrackingState> _trackPersonnel(TrackPersonnel event) async {
    var response = await service.create(
      incidentBloc.current.id,
      devices: event.data,
    );
    if (response.is200) {
      await personnelBloc.update(
        event.personnel.cloneWith(tracking: response.body.id),
      );
      final tracking = _tracking.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK(event, TrackingCreated(tracking), result: tracking);
    }
    return _toError(event, response);
  }

  TrackingState _process(TrackingMessage event) {
    switch (event.type) {
      case TrackingMessageType.TrackingChanged:
        // Only handle tracking in current incident
        if (event.incidentId == incidentBloc?.current?.id) {
          var tracking = Tracking.fromJson(event.json);
          // Update or add as new
          return TrackingUpdated(_tracking.update(tracking.id, (_) => tracking, ifAbsent: () => tracking));
        }
        break;
      case TrackingMessageType.LocationChanged:
        var id = event.json['id'];
        if (_tracking.containsKey(id)) {
          return TrackingUpdated(
            _tracking.update(id, (tracking) => tracking.cloneWith(point: Point.fromJson(event.json))),
          );
        }
        break;
    }
    return TrackingError("Tracking message not recognized: $event");
  }

  Future<TrackingState> _update(UpdateTracking event) async {
    var response = await service.update(event.data);
    if (response.is200) {
      final tracking = response.body;
      _tracking.update(
        tracking.id,
        (_) => tracking,
        ifAbsent: () => tracking,
      );
      return _toOK(event, TrackingUpdated(tracking), result: tracking);
    }
    return _toError(event, response);
  }

  Future<TrackingState> _delete(DeleteTracking event) async {
    var response = await service.delete(event.data);
    if (response.is204) {
      if (_tracking.remove(event.data.id) == null) {
        return _toError(event, "Failed to delete tracking $event, not found locally");
      }
      return _toOK(event, TrackingDeleted(event.data));
    }
    return _toError(event, response);
  }

  TrackingCleared _clear(ClearTracking command) {
    List<Tracking> cleared = [];
    command.data.forEach((id) => {if (_tracking.containsKey(id)) cleared.add(_tracking.remove(id))});
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
  void onError(Object error, StackTrace stackTrace) {
    if (_subscriptions.isNotEmpty) {
      dispatch(RaiseTrackingError(TrackingError(error, trace: stackTrace)));
    } else {
      throw "Bad state: TrackingBloc is disposed. Unexpected ${TrackingError(error, trace: stackTrace)}";
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

class TrackUnit extends TrackingCommand<List<String>, Tracking> {
  final Unit unit;
  final List<Personnel> personnel;
  TrackUnit(this.unit, {List<String> devices, this.personnel}) : super(devices);

  @override
  String toString() => 'TrackUnit';
}

class TrackPersonnel extends TrackingCommand<List<String>, Tracking> {
  final Personnel personnel;
  TrackPersonnel(this.personnel, {List<String> devices}) : super(devices);

  @override
  String toString() => 'TrackPersonnel';
}

class UpdateTracking extends TrackingCommand<Tracking, Tracking> {
  UpdateTracking(Tracking data) : super(data);

  @override
  String toString() => 'UpdateTracking';
}

class _HandleMessage extends TrackingCommand<TrackingMessage, void> {
  _HandleMessage(TrackingMessage data) : super(data);

  @override
  String toString() => '_HandleMessage';
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

/// Helper class for querying tracked entities
class Entities<T> {
  final TrackingBloc bloc;
  final Map<String, T> _data;
  final String Function(T entity) asId;

  Entities({
    /// [TrackingBloc] managing tracking objects
    @required this.bloc,

    /// Mapping from entity id to value object
    @required Map<String, T> data,

    /// Mapping from entity to tracking id
    @required this.asId,
  }) : this._data = data;

  /// Test if entity is being tracked
  bool contains(
    T entity, {
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      asId(entity) != null &&
      bloc.tracking.containsKey(asId(entity)) &&
      !exclude.contains(bloc.tracking[asId(entity)].status);

  /// Get entry with given tracking id
  T elementAt(
    String tracking, {
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      _data.values.firstWhere(
        (entity) => contains(entity, exclude: exclude) && tracking == asId(entity),
        orElse: () => null,
      );

  /// Find entity tracking given device
  T find(
    Device device, {
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      asTrackingIds(exclude: exclude).values.firstWhere(
            (entity) =>
                null !=
                bloc.devices(asId(entity), exclude: exclude).firstWhere(
                      (match) => device.id == match.id,
                      orElse: () => null,
                    ),
            orElse: () => null,
          );

  /// Check if given entity is

  /// Get entities being tracked as a map of tracking id to entity object
  Map<String, T> asTrackingIds({
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      UnmodifiableMapView(
        Map.fromEntries(
          _data.entries.where((entry) => contains(entry.value, exclude: exclude)),
        ),
      );

  /// Get entities for all tracked devices.
  Map<String, T> asDeviceIds({
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) {
    final Map<String, T> map = {};
    asTrackingIds(exclude: exclude).values.forEach((entity) {
      bloc.devices(asId(entity), exclude: exclude).forEach((device) {
        map.update(device.id, (set) => entity, ifAbsent: () => entity);
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Get devices being tracked by entities of given type
  Map<String, Device> devices({
    List<TrackingStatus> exclude: const [TrackingStatus.Closed],
  }) =>
      UnmodifiableMapView(
        Map.fromEntries(
          _data.values
              .where((entity) => contains(entity, exclude: exclude))
              .map((entry) => bloc.tracking[asId(entry)]?.devices ?? [])
              .reduce((l1, l2) => List.from(l1)..addAll(l2))
              .map((id) => MapEntry(id, bloc.deviceBloc.devices[id])),
        ),
      );
}
