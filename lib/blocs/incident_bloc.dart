import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class IncidentBloc extends Bloc<IncidentCommand, IncidentState> {
  final IncidentService service;
  final UserBloc userBloc;

  final LinkedHashMap<String, Incident> _incidents = LinkedHashMap();

  String _given;
  StreamSubscription _subscription;

  IncidentBloc(this.service, this.userBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");
    _subscription = userBloc.state.listen(_init);
  }

  void _init(UserState state) {
    if (_subscription != null) {
      if (!state.isUnset() && state.isUnset()) {
        dispatch(ClearIncidents(_incidents.keys.toList()));
        if (_given != null) dispatch(UnsetIncident());
      } else if (state.isAuthenticated()) fetch();
    }
  }

  @override
  IncidentState get initialState => IncidentUnset();

  /// Check if [incidents] is empty
  bool get isEmpty => incidents.isEmpty;

  /// Check if incident is unset
  bool get isUnset => _given == null;

  /// Get current incident
  Incident get current => _incidents[this._given];

  /// Get incidents
  List<Incident> get incidents => UnmodifiableListView<Incident>(_incidents.values);

  /// Stream of switched between given incidents
  Stream<Incident> get switches => state
      .where(
        (state) => state is IncidentSelected && state.data.id != _given,
      )
      .map((state) => state.data);

  /// Stream of incident changes
  Stream<Incident> get changes => state
      .where(
        (state) => state.isCreated() || state.isUpdated() || state.isSelected(),
      )
      .map((state) => state.data);

  /// Fetch incidents from [service]
  Future<List<Incident>> fetch() async {
    var response = await service.fetch();
    if (response.is200) {
      dispatch(ClearIncidents(_incidents.keys.toList()));
      return _dispatch(LoadIncidents(response.body));
    }
    dispatch(RaiseIncidentError(response));
    return Future.error(response);
  }

  /// Select given id
  Future<void> select(String id) {
    if (_given != id && _incidents.containsKey(id)) {
      return _dispatch(SelectIncident(id));
    }
    return Future.value();
  }

  /// Create given incident
  Future<Incident> create(Incident incident, [bool selected = true]) {
    return _dispatch<Incident>(CreateIncident(incident, selected: selected));
  }

  /// Update given incident
  Future<void> update(Incident incident, [bool selected = true]) {
    return _dispatch(UpdateIncident(incident, selected: selected));
  }

  /// Delete given incident
  Future<void> delete(Incident incident) {
    return _dispatch(DeleteIncident(incident));
  }

  /// Clear all incidents
  Future<void> clear() {
    return _dispatch(ClearIncidents(_incidents.keys.toList()));
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand command) async* {
    if (command is LoadIncidents) {
      final loaded = _load(command);
      // Currently selected incident not found?
      if (_given != null && _given.isNotEmpty && !_incidents.containsKey(_given)) {
        yield _unset();
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
        var select = command.selected && command.data.id != _given;
        if (select) {
          yield _set(command.data);
        }
        yield updated;
      }
    } else if (command is SelectIncident) {
      if (command.data != _given && _incidents.containsKey(command.data)) {
        yield _select(command);
      }
    } else if (command is DeleteIncident) {
      final deleted = await _delete(command);
      if (deleted.isDeleted() && command.data.id == _given) {
        yield _unset();
      }
      yield deleted;
    } else if (command is ClearIncidents) {
      yield _clear(command);
    } else if (command is UnsetIncident) {
      yield _unset();
    } else if (command is RaiseIncidentError) {
      yield command.data;
    } else {
      yield IncidentError("Unsupported $command");
    }
  }

  IncidentState _load(LoadIncidents command) {
    _incidents.addEntries((command.data).map(
      (incident) => MapEntry(incident.id, incident),
    ));
    return _toOK<List<Incident>>(
      command,
      IncidentsLoaded(_incidents.keys.toList()),
      result: _incidents.values.toList(),
    );
  }

  Future<IncidentState> _create(CreateIncident event) async {
    var response = await service.create(event.data);
    if (response.is200) {
      _incidents.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK<Incident>(event, IncidentCreated(response.body), result: response.body);
    }
    return _toError(event, response);
  }

  Future<IncidentState> _update(UpdateIncident event) async {
    var response = await service.update(event.data);
    if (response.is204) {
      _incidents.update(
        event.data.id,
        (_) => event.data,
        ifAbsent: () => event.data,
      );
      // All tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, IncidentUpdated(event.data));
    }
    return _toError(event, response);
  }

  Future<IncidentState> _delete(DeleteIncident event) async {
    var response = await service.delete(event.data);
    if (response.is204) {
      if (_incidents.remove(event.data.id) == null) {
        return _toError(event, "Failed to delete incident $event, not found locally");
      }
      // All tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, IncidentDeleted(event.data));
    }
    return _toError(event, response);
  }

  IncidentSelected _select(SelectIncident command) {
    return _toOK(command, _set(_incidents[command.data]));
  }

  IncidentSelected _set(Incident data) {
    _given = data.id;
    return IncidentSelected(data);
  }

  IncidentUnset _unset() {
    final incident = _incidents[_given];
    _given = null;
    return IncidentUnset(incident);
  }

  IncidentState _clear(ClearIncidents command) {
    List<Incident> cleared = [];
    command.data.forEach((id) => {if (_incidents.containsKey(id)) cleared.add(_incidents.remove(id))});
    return _toOK(command, IncidentsCleared(cleared));
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(IncidentCommand<T> command) {
    dispatch(command);
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
  Future<IncidentState> _toError(IncidentCommand event, Object response) async {
    final error = IncidentError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscription != null) {
      dispatch(RaiseIncidentError(IncidentError(error, trace: stacktrace)));
    } else {
      throw "Bad state: IncidentBloc is disposed. Unexpected ${IncidentError(error, trace: stacktrace)}";
    }
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
    _subscription = null;
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<T> extends Equatable {
  final T data;
  final Completer<T> callback = Completer();

  IncidentCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadIncidents extends IncidentCommand<List<Incident>> {
  LoadIncidents(List<Incident> data) : super(data);

  @override
  String toString() => 'LoadIncidents';
}

class CreateIncident extends IncidentCommand<Incident> {
  final bool selected;
  CreateIncident(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'CreateIncident';
}

class UpdateIncident extends IncidentCommand<Incident> {
  final bool selected;
  UpdateIncident(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'UpdateIncident';
}

class SelectIncident extends IncidentCommand<String> {
  SelectIncident(String id) : super(id);

  @override
  String toString() => 'SelectIncident';
}

class DeleteIncident extends IncidentCommand<Incident> {
  DeleteIncident(Incident data) : super(data);

  @override
  String toString() => 'DeleteIncident';
}

class ClearIncidents extends IncidentCommand<List<String>> {
  ClearIncidents(List<String> data) : super(data);

  @override
  String toString() => 'ClearIncidents';
}

class UnsetIncident extends IncidentCommand<void> {
  UnsetIncident() : super(null);

  @override
  String toString() => 'UnsetIncident';
}

class RaiseIncidentError extends IncidentCommand<IncidentError> {
  RaiseIncidentError(data) : super(data);

  @override
  String toString() => 'RaiseIncidentError';
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

class IncidentsLoaded extends IncidentState<List<String>> {
  IncidentsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'IncidentsLoaded';
}

class IncidentCreated extends IncidentState<Incident> {
  final bool selected;
  IncidentCreated(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'IncidentCreated';
}

class IncidentUpdated extends IncidentState<Incident> {
  final bool selected;
  IncidentUpdated(Incident data, {this.selected = true}) : super(data, [selected]);

  @override
  String toString() => 'IncidentUpdated';
}

class IncidentSelected extends IncidentState<Incident> {
  IncidentSelected(Incident data) : super(data);

  @override
  String toString() => 'IncidentSelected';
}

class IncidentDeleted extends IncidentState<Incident> {
  IncidentDeleted(Incident data) : super(data);

  @override
  String toString() => 'IncidentDeleted';
}

class IncidentsCleared extends IncidentState<List<Incident>> {
  IncidentsCleared(List<Incident> incidents) : super(incidents);

  @override
  String toString() => 'IncidentsCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class IncidentException extends IncidentState<Object> {
  final StackTrace trace;
  IncidentException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'IncidentException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class IncidentError extends IncidentException {
  final StackTrace trace;
  IncidentError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'IncidentError {data: $data}';
}
