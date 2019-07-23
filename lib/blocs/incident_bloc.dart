import 'dart:collection';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

class IncidentBloc extends Bloc<IncidentCommand, IncidentState> {
  final IncidentService service;
  final UserBloc userBloc;

  final LinkedHashMap<String, Incident> _incidents = LinkedHashMap();

  String _given;

  IncidentBloc(this.service, this.userBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");
    userBloc.state.listen(_init);
  }

  void _init(UserState state) {
    if (state.isUnset() || state.isForbidden() || state.isUnauthorized())
      dispatch(ClearIncidents(_incidents.keys.toList()));
    else if (state.isAuthenticated()) fetch();
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
    dispatch(ClearIncidents(_incidents.keys.toList()));
    var incidents = await service.fetch();
    dispatch(LoadIncidents(incidents));
    return UnmodifiableListView<Incident>(incidents);
  }

  /// Select given id
  IncidentBloc select(String id) {
    if (_given != id && _incidents.containsKey(id)) {
      dispatch(SelectIncident(id));
    }
    return this;
  }

  /// Create given incident
  IncidentBloc create(Incident incident, [bool selected = true]) {
    dispatch(CreateIncident(incident, selected: selected));
    return this;
  }

  /// Update given incident
  IncidentBloc update(Incident incident, [bool selected = true]) {
    dispatch(UpdateIncident(incident, selected: selected));
    return this;
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand command) async* {
    if (command is LoadIncidents) {
      List<String> ids = _load(command);
      yield IncidentsLoaded(ids);
      // Currently selected incident not found?
      if (_given != null && _given.isNotEmpty && !_incidents.containsKey(_given)) {
        yield _unset();
      }
    } else if (command is CreateIncident) {
      Incident data = await _create(command);
      if (command.selected) {
        yield _set(data);
      }
    } else if (command is UpdateIncident) {
      Incident data = await _update(command);
      var select = command.selected && data.id != _given;
      yield IncidentUpdated(data, selected: (data.id == _given || select));
      if (select) {
        yield _set(data);
      }
    } else if (command is SelectIncident) {
      if (command.data != _given && _incidents.containsKey(command.data)) {
        yield _set(_incidents[command.data]);
      }
    } else if (command is DeleteIncident) {
      Incident data = await _delete(command);
      if (data.id == _given) {
        yield _unset();
      }
    } else if (command is ClearIncidents) {
      List<Incident> incidents = _clear(command);
      yield IncidentsCleared(incidents);
    } else if (command is RaiseIncidentError) {
      yield command.data;
    } else {
      yield IncidentError("Unsupported $command");
    }
  }

  List<String> _load(LoadIncidents command) {
    _incidents.addEntries((command.data).map(
      (incident) => MapEntry(incident.id, incident),
    ));
    return _incidents.keys.toList();
  }

  Future<Incident> _create(CreateIncident event) async {
    //TODO: Implement call to backend

    var data = _incidents.putIfAbsent(
      event.data.id,
      () => event.data,
    );
    return Future.value(data);
  }

  Future<Incident> _update(UpdateIncident event) async {
    //TODO: Implement call to backend

    var data = _incidents.update(
      event.data.id,
      (incident) => event.data,
      ifAbsent: () => event.data,
    );
    return Future.value(data);
  }

  Future<Incident> _delete(DeleteIncident event) {
    //TODO: Implement call to backend

    if (this.incidents.remove(event.data.id)) {
      throw "Failed to delete ${event.data.id}";
    }
    return Future.value(event.data);
  }

  IncidentSelected _set(Incident data) {
    _given = data.id;
    return IncidentSelected(data);
  }

  IncidentUnset _unset() {
    _given = null;
    return IncidentUnset();
  }

  List<Incident> _clear(ClearIncidents command) {
    List<Incident> cleared = [];
    command.data.forEach((id) => {if (_incidents.containsKey(id)) cleared.add(_incidents.remove(id))});
    return cleared;
  }

  @override
  void onEvent(IncidentCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<IncidentCommand, IncidentState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseIncidentError(IncidentError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<T> extends Equatable {
  final T data;

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

class IncidentUnset extends IncidentState<Null> {
  IncidentUnset() : super(null);

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
