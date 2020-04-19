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
    assert(this.service1 != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");
    _subscription = userBloc.listen(_init);
  }

  final UserBloc userBloc;
  final IncidentRepository repo;

  IncidentService get service1 => repo.service;

  String _uuid;
  StreamSubscription _subscription;

  void _init(UserState state) {
    if (_subscription != null) {
      if (!isUnset && state.isUnset()) {
        if (!isUnset) {
          add(UnselectIncident());
        }
        add(ClearIncidents());
      } else if (state.isAuthenticated()) {
        add(LoadIncidents());
      }
    }
  }

  @override
  IncidentState get initialState => IncidentUnset();

  /// Check if no incident selected
  bool get isUnset => _uuid == null;

  /// Get selected incident
  Incident get selected => repo[_uuid];

  /// Get incident from uuid
  Incident at(String uuid) => repo[uuid];

  /// Get incidents
  List<Incident> get incidents => repo.values;

  /// Stream of switched between given incidents
  Stream<Incident> get switches => where(
        (state) => state is IncidentSelected && state.data.uuid != _uuid,
      ).map((state) => state.data);

  /// Stream of incident changes
  Stream<Incident> changes([Incident incident]) => where(
        (state) => _isOn(incident, state) && state.isCreated() || state.isUpdated() || state.isSelected(),
      ).map((state) => state.data);

  bool _isOn(Incident incident, IncidentState state) => (incident == null || state.data.uuid == incident.uuid);

  /// Fetch incidents from [repo]
  Future<List<Incident>> load() async {
    return _dispatch(LoadIncidents());
  }

  /// Select [Incident] with given [Incident.uuid]
  Future<Incident> select(String uuid) {
    if (emptyAsNull(uuid) == null) {
      throw ArgumentError('Incident uuid can not be null');
    }
    return _dispatch(SelectIncident(uuid));
  }

  /// Unselect [selected]
  Future<Incident> unselect() {
    return _dispatch(UnselectIncident());
  }

  /// Create given incident
  Future<Incident> create(Incident incident, [bool selected = true]) {
    return _dispatch<Incident>(CreateIncident(incident, selected: selected));
  }

  /// Update given incident
  Future<Incident> update(Incident incident, [bool selected = true]) {
    return _dispatch(UpdateIncident(incident, selected: selected));
  }

  /// Delete given incident
  Future<Incident> delete(String uuid) {
    return _dispatch(DeleteIncident(uuid));
  }

  /// Clear all incidents
  Future<void> clear() {
    return _dispatch(ClearIncidents());
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand command) async* {
    if (command is LoadIncidents) {
      final loaded = await _load(command);
      // Currently selected incident not found?
      if (!(isUnset || repo.containsKey(_uuid))) {
        yield _unselect();
      }
      yield loaded;
    } else if (command is CreateIncident) {
      final created = await _create(command);
      if (created.isCreated() && command.selected) {
        yield _set(created.data);
      }
      yield created;
    } else if (command is UpdateIncident) {
      final updated = await _update(command);
      if (updated.isUpdated()) {
        var select = command.selected && command.data.uuid != _uuid;
        if (select) {
          yield _set(command.data);
        }
      }
      yield updated;
    } else if (command is SelectIncident) {
      yield _select(command);
    } else if (command is DeleteIncident) {
      final deleted = await _delete(command);
      if (deleted.isDeleted() && command.data == _uuid) {
        yield _unselect();
      }
      yield deleted;
    } else if (command is ClearIncidents) {
      yield await _clear(command);
    } else if (command is UnselectIncident) {
      yield _unselect(event: command);
    } else if (command is RaiseIncidentError) {
      yield command.data;
    } else {
      yield _toError(
        command,
        IncidentError("Unsupported $command"),
      );
    }
  }

  Future<IncidentState> _load(LoadIncidents command) async {
    final incidents = await repo.load();
    return _toOK(
      command,
      IncidentsLoaded(incidents),
      result: repo.values.toList(),
    );
  }

  Future<IncidentState> _create(CreateIncident event) async {
    var incident = await repo.create(event.data);
    return _toOK<Incident>(
      event,
      IncidentCreated(incident),
      result: incident,
    );
  }

  Future<IncidentState> _update(UpdateIncident event) async {
    var incident = await repo.update(event.data);
    return _toOK<Incident>(
      event,
      IncidentUpdated(incident),
      result: incident,
    );
  }

  Future<IncidentState> _delete(DeleteIncident event) async {
    var incident = await repo.delete(event.data);
    return _toOK<Incident>(
      event,
      IncidentDeleted(incident),
      result: incident,
    );
  }

  IncidentState _select(SelectIncident command) {
    if (repo.containsKey(command.data)) {
      final incident = repo[command.data];
      return _toOK(
        command,
        _set(repo[command.data]),
        result: incident,
      );
    }
    return _toError(
      command,
      IncidentError('Incident ${command.data} not found locally'),
    );
  }

  IncidentSelected _set(Incident data) {
    _uuid = data.uuid;
    return IncidentSelected(data);
  }

  IncidentState _unselect({IncidentCommand event}) {
    final incident = repo[_uuid];
    if (incident == null) {
      return _toError(event, IncidentError('No incident was selected'));
    }
    _uuid = null;
    if (event != null) {
      return _toOK(event, IncidentUnset(incident), result: incident);
    }
    return IncidentUnset(incident);
  }

  Future<IncidentState> _clear(ClearIncidents command) async {
    List<Incident> cleared = await repo.clear();
    return _toOK(
      command,
      IncidentsCleared(cleared),
    );
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
  IncidentState _toError(IncidentCommand event, Object response) {
    final error = IncidentError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscription != null) {
      add(RaiseIncidentError(IncidentError(error, stackTrace: stacktrace)));
    } else {
      throw "Bad state: IncidentBloc is disposed. Unexpected ${IncidentError(error, stackTrace: stacktrace)}";
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _subscription?.cancel();
    _subscription = null;
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();

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

class ClearIncidents extends IncidentCommand<void, List<Incident>> {
  ClearIncidents() : super(null);

  @override
  String toString() => 'ClearIncidents {}';
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

  isUnset() => this is IncidentUnset;
  isLoaded() => this is IncidentsLoaded;
  isCreated() => this is IncidentCreated;
  isUpdated() => this is IncidentUpdated;
  isSelected() => this is IncidentSelected;
  isDeleted() => this is IncidentDeleted;
  isException() => this is IncidentException;
  isError() => this is IncidentError;
}

class IncidentUnset extends IncidentState<Incident> {
  IncidentUnset([Incident incident]) : super(incident);

  @override
  String toString() => 'IncidentUnset';
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

class IncidentsCleared extends IncidentState<Iterable<Incident>> {
  IncidentsCleared(Iterable<Incident> incidents) : super(incidents);

  @override
  String toString() => 'IncidentsCleared {incidents: $data}';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class IncidentException extends IncidentState<Object> {
  final StackTrace stackTrace;
  IncidentException(Object error, {this.stackTrace}) : super(error, [stackTrace]);

  @override
  String toString() => 'IncidentException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class IncidentError extends IncidentException {
  final StackTrace stackTrace;
  IncidentError(Object error, {this.stackTrace}) : super(error, stackTrace: stackTrace);

  @override
  String toString() => 'IncidentError {data: $data, stackTrace: $stackTrace}';
}
