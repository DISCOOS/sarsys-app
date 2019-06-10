import 'dart:collection';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

typedef void IncidentCallback(VoidCallback fn);

class IncidentBloc extends Bloc<IncidentCommand, IncidentState> {
  final IncidentService service;

  final LinkedHashMap<String, Incident> _incidents = LinkedHashMap();

  String _given;

  IncidentBloc(this.service);

  @override
  IncidentState get initialState => IncidentUnset();

  /// Check if [incidents] is empty
  bool get isEmpty => incidents.isEmpty;

  /// Check if incident is unset
  bool get isUnset => _given == null;

  /// Get current incident
  Incident get current => _incidents[this._given];

  /// Get incidents
  List<Incident> get incidents => _incidents.values.toList();

  /// Stream of switched between given incidents
  Stream<Incident> get switches => state
      .where(
        (state) => state is IncidentSelected && state.data.id != _given,
      )
      .map((state) => state.data);

  /// Initialize if empty
  IncidentBloc init(IncidentCallback onInit) {
    if (isEmpty) {
      fetch().then((_) => onInit(() {}));
    }
    return this;
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

  /// Fetch incidents from [service]
  Future<List<Incident>> fetch() async {
    _incidents.clear();
    _incidents.addEntries((await service.fetch()).map(
      (incident) => MapEntry(incident.id, incident),
    ));
    if (_incidents.containsKey(_given)) {
      this.dispatch(SelectIncident(_given));
    }
    return UnmodifiableListView<Incident>(_incidents.values);
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand command) async* {
    if (command is CreateIncident) {
      Incident data = await _create(command);
      if (command.selected) {
        yield _set(data);
      }
    } else if (command is UpdateIncident) {
      Incident data = await _update(command);
      if (command.selected || data.id == _given) {
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
    } else if (command is RaiseIncidentError) {
      yield command.data;
    } else {
      yield IncidentError("Unsupported $command");
    }
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
