import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/repositories/incident_repository.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class IncidentBloc extends Bloc<IncidentCommand, IncidentState> {
  IncidentBloc(this.repo, this.userBloc) {
    assert(this.repo != null, "repository can not be null");
    assert(this.repo.service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");
    _subscription = userBloc.listen(
      _processUserEvent,
    );
  }

  /// Get [UserBloc]
  final UserBloc userBloc;

  /// Get [IncidentRepository]
  final IncidentRepository repo;

  /// Get [IncidentService]
  IncidentService get service => repo.service;

  String _uuid;
  StreamSubscription _subscription;

  void _processUserEvent(UserState state) {
    if (_subscription != null) {
      if (!isUnset && state.isUnset()) {
        if (!isUnset) {
          add(UnselectIncident());
        }
      } else if (state.isAuthenticated()) {
        add(LoadIncidents());
      }
    }
  }

  @override
  IncidentUnset get initialState => IncidentUnset();

  /// Check if no incident selected
  bool get isUnset => _uuid == null;

  /// Get selected incident
  Incident get selected => repo[_uuid];

  /// Get incident from uuid
  Incident get(String uuid) => repo[uuid];

  /// Get incidents
  List<Incident> get incidents => repo.values;

  /// Stream of switched between given incidents
  Stream<Incident> get onSwitched => where(
        (state) => state is IncidentSelected && state.data.uuid != _uuid,
      ).map((state) => state.data);

  /// Stream of incident changes
  Stream<Incident> onChanged([Incident incident]) => where(
        (state) => _isOn(incident, state) && state.isCreated() || state.isUpdated() || state.isSelected(),
      ).map((state) => state.data);

  bool _isOn(Incident incident, IncidentState state) => (incident == null || state.data.uuid == incident.uuid);

  /// Fetch incidents from [repo]
  Future<List<Incident>> load() async {
    return _dispatch(
      LoadIncidents(),
    );
  }

  /// Select [Incident] with given [Incident.uuid]
  Future<Incident> select(String uuid) {
    if (emptyAsNull(uuid) == null) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    return _dispatch(SelectIncident(uuid));
  }

  /// Unselect [selected]
  Future<Incident> unselect() {
    return _dispatch(UnselectIncident());
  }

  /// Create given incident
  Future<Incident> create(Incident incident, {bool selected = true}) {
    return _dispatch<Incident>(CreateIncident(incident, selected: selected));
  }

  /// Update given incident
  Future<Incident> update(Incident incident, {bool selected = true}) {
    return _dispatch(UpdateIncident(incident, selected: selected));
  }

  /// Delete given incident
  Future<Incident> delete(String uuid) {
    if (isEmptyOrNull(uuid)) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    return _dispatch(DeleteIncident(uuid));
  }

  /// Clear all incidents
  Future<void> unload() {
    return _dispatch(UnloadIncidents());
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand command) async* {
    if (command is LoadIncidents) {
      yield* _load(command);
    } else if (command is CreateIncident) {
      yield* _create(command);
    } else if (command is UpdateIncident) {
      yield* _update(command);
    } else if (command is SelectIncident) {
      yield* _select(command);
    } else if (command is DeleteIncident) {
      yield* _delete(command);
    } else if (command is UnloadIncidents) {
      yield* _unload(command);
    } else if (command is UnselectIncident) {
      yield _unselect(command);
    } else if (command is RaiseIncidentError) {
      yield _toError(
        command,
        command.data,
      );
    } else {
      yield _toError(
        command,
        IncidentError(
          "Unsupported $command",
          stackTrace: StackTrace.current,
        ),
      );
    }
  }

  Stream<IncidentState> _load(LoadIncidents command) async* {
    // Execute command
    final incidents = await repo.load();
    // Currently selected incident not found?
    final unselected = _unset();
    // Complete request
    final loaded = _toOK(
      command,
      IncidentsLoaded(incidents),
      result: repo.values.toList(),
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield loaded;
  }

  Stream<IncidentState> _create(CreateIncident command) async* {
    // Execute command
    final incident = await repo.create(command.data);
    // Complete request
    final created = _toOK<Incident>(
      command,
      IncidentCreated(incident),
      result: incident,
    );
    final unselected = command.selected ? _unset() : null;
    final selected = command.selected ? _set(incident) : null;
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield created;
    if (selected != null) {
      yield selected;
    }
  }

  Stream<IncidentState> _update(UpdateIncident command) async* {
    // Execute command
    var incident = await repo.update(command.data);
    var select = command.selected && command.data.uuid != _uuid;
    final unselected = select ? _unset() : null;
    final selected = select ? _set(incident) : null;
    final selectionChanged = unselected != selected;
    // Complete request
    final updated = _toOK<Incident>(
      command,
      IncidentUpdated(incident),
      result: incident,
    );
    // Notify listeners
    if (selectionChanged) {
      if (unselected != null) {
        yield unselected;
      }
    }
    yield updated;
    if (selectionChanged) {
      if (selected != null) {
        yield selected;
      }
    }
  }

  Stream<IncidentState> _delete(DeleteIncident command) async* {
    // Execute command
    var incident = await repo.delete(command.data);
    // Unselect if was selected
    final unselected = command.data == _uuid ? _unset(incident) : null;
    // Complete request
    final deleted = _toOK<Incident>(
      command,
      IncidentDeleted(incident),
      result: incident,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield deleted;
  }

  Stream<IncidentState> _unload(UnloadIncidents command) async* {
    final incident = selected;
    // Execute command
    List<Incident> incidents = await repo.clear();
    // Complete request
    final unselected = _unset(incident);
    final unloaded = _toOK(
      command,
      IncidentsUnloaded(incidents),
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield unloaded;
  }

  Stream<IncidentState> _select(SelectIncident command) async* {
    if (repo.containsKey(command.data)) {
      final incident = repo[command.data];
      final unselected = _unset();
      final selected = _toOK(
        command,
        _set(repo[command.data]),
        result: incident,
      );
      if (unselected != selected) {
        if (unselected != null) {
          yield unselected;
        }
        if (selected != null) {
          yield selected;
        }
      }
    } else {
      yield _toError(
        command,
        IncidentError(
          'Incident ${command.data} not found locally',
          stackTrace: command.stackTrace,
        ),
      );
    }
  }

  IncidentSelected _set(Incident data) {
    _uuid = data.uuid;
    return IncidentSelected(data);
  }

  IncidentState _unselect(IncidentCommand command) {
    final unselected = _unset();
    if (unselected != null) {
      return _toOK(
        command,
        unselected,
        result: unselected.data,
      );
    }
    return _toError(
      command,
      IncidentError('No incident was selected'),
    );
  }

  IncidentState _unset([Incident selected]) {
    final incident = repo[_uuid] ?? selected;
    _uuid = null;
    return incident != null ? IncidentUnset(incident) : null;
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(IncidentCommand<Object, T> command) {
    add(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  IncidentState _toOK<T>(IncidentCommand event, IncidentState state, {T result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  IncidentState _toError(IncidentCommand event, Object error) {
    final object = error is IncidentError
        ? error
        : IncidentError(
            error,
            stackTrace: StackTrace.current,
          );
    event.callback.completeError(
      object,
      object.stackTrace,
    );
    return object;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscription != null) {
      add(RaiseIncidentError(IncidentError(
        error,
        stackTrace: stacktrace,
      )));
    } else {
      throw IncidentBlocException(
        error,
        state,
        stackTrace: stacktrace,
      );
    }
  }

  @override
  Future<void> close() async {
    _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();
  final StackTrace stackTrace = StackTrace.current;

  IncidentCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadIncidents extends IncidentCommand<void, List<Incident>> {
  LoadIncidents() : super(null);

  @override
  String toString() => 'LoadIncidents {}';
}

class CreateIncident extends IncidentCommand<Incident, Incident> {
  final bool selected;
  CreateIncident(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'CreateIncident {data: $data, selected: $selected}';
}

class UpdateIncident extends IncidentCommand<Incident, Incident> {
  final bool selected;
  UpdateIncident(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'UpdateIncident {data: $data, selected: $selected}';
}

class SelectIncident extends IncidentCommand<String, Incident> {
  SelectIncident(String uuid) : super(uuid);

  @override
  String toString() => 'SelectIncident {data: $data}';
}

class UnselectIncident extends IncidentCommand<void, Incident> {
  UnselectIncident() : super(null);

  @override
  String toString() => 'UnselectIncident';
}

class DeleteIncident extends IncidentCommand<String, Incident> {
  DeleteIncident(String uuid) : super(uuid);

  @override
  String toString() => 'DeleteIncident {data: $data}';
}

class UnloadIncidents extends IncidentCommand<void, List<Incident>> {
  UnloadIncidents() : super(null);

  @override
  String toString() => 'UnloadIncidents {}';
}

class RaiseIncidentError extends IncidentCommand<Object, IncidentError> {
  RaiseIncidentError(data) : super(data);

  @override
  String toString() => 'RaiseIncidentError {data: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class IncidentState<T> extends Equatable {
  final T data;

  IncidentState(this.data, [props = const []]) : super([data, ...props]);

  bool isUnset() => this is IncidentUnset;
  bool isLoaded() => this is IncidentsLoaded;
  bool isCreated() => this is IncidentCreated;
  bool isUpdated() => this is IncidentUpdated;
  bool isSelected() => this is IncidentSelected;
  bool isDeleted() => this is IncidentDeleted;
  bool isError() => this is IncidentError;

  /// Check if data referencing [Incident.uuid] should be unloaded
  /// This method will return true if
  /// 1. IncidentBloc was unset
  /// 2. Given Incident was changed to a status that should unload data
  bool shouldUnload(String uuid,
          {List<IncidentStatus> include: const [
            IncidentStatus.Resolved,
            IncidentStatus.Cancelled,
          ]}) =>
      isUnset() ||
      (isUpdated() && (this as IncidentUpdated).data.uuid == uuid) &&
          include.contains(
            (this as IncidentUpdated).data.status,
          );
}

class IncidentUnset extends IncidentState<Incident> {
  IncidentUnset([Incident incident]) : super(incident);

  @override
  String toString() => 'IncidentUnset {incident: $data}';
}

class IncidentsLoaded extends IncidentState<Iterable<Incident>> {
  IncidentsLoaded(Iterable<Incident> data) : super(data);

  @override
  String toString() => 'IncidentsLoaded {incidents: $data}';
}

class IncidentCreated extends IncidentState<Incident> {
  final bool selected;
  IncidentCreated(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'IncidentCreated {incident: $data, selected: $selected}';
}

class IncidentUpdated extends IncidentState<Incident> {
  final bool selected;
  IncidentUpdated(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'IncidentUpdated {incident: $data, selected: $selected}';
}

class IncidentSelected extends IncidentState<Incident> {
  IncidentSelected(Incident data) : super(data);

  @override
  String toString() => 'IncidentSelected {incident: $data,}';
}

class IncidentDeleted extends IncidentState<Incident> {
  IncidentDeleted(Incident data) : super(data);

  @override
  String toString() => 'IncidentDeleted {incident: $data}';
}

class IncidentsUnloaded extends IncidentState<Iterable<Incident>> {
  IncidentsUnloaded(Iterable<Incident> incidents) : super(incidents);

  @override
  String toString() => 'IncidentsUnloaded {incidents: $data}';
}

/// ---------------------
/// Error States
/// ---------------------
class IncidentError extends IncidentState<Object> {
  final StackTrace stackTrace;
  IncidentError(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => 'runtimeType {error: $data}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class IncidentBlocException implements Exception {
  IncidentBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final IncidentState state;
  final StackTrace stackTrace;
  final IncidentCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
