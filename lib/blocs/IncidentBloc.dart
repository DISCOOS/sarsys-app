import 'dart:collection';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void FetchCallback(VoidCallback fn);

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
  Stream<Incident> get switches =>
      state.where((state) => state is IncidentSelected && state.data.id != _given).map((state) => state.data);

  /// Initialize if empty
  IncidentBloc init(FetchCallback onFetch) {
    if (isEmpty) {
      fetch().then((_) => onFetch(() {}));
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

  /// Fetch incidents from [service]
  Future<List<Incident>> fetch() async {
    this._incidents.clear();
    this._incidents.addEntries((await service.fetchIncidents()).map(
          (incident) => MapEntry(incident.id, incident),
        ));
    if (this._incidents.containsKey(this._given)) {
      this.dispatch(SelectIncident(this._given));
    }
    return UnmodifiableListView<Incident>(this._incidents.values);
  }

  @override
  Stream<IncidentState> mapEventToState(IncidentCommand event) async* {
    if (event is CreateIncident) {
      Incident data = _create(event);
      if (event.selected) {
        yield _set(data);
      }
    } else if (event is UpdateIncident) {
      Incident data = _update(event);
      if (event.selected || data.id == this._given) {
        yield _set(data);
      }
    } else if (event is SelectIncident) {
      if (event.data != this._given && _incidents.containsKey(event.data)) {
        yield _set(_incidents[event.data]);
      }
    } else if (event is DeleteIncident) {
      Incident data = _delete(event);
      if (data.id == this._given) {
        yield _unset();
      }
    } else {
      throw "Unsupported $event";
    }
  }

  Incident _create(CreateIncident event) {
    //TODO: Implement call to backend

    var data = this._incidents.putIfAbsent(
          event.data.id,
          () => event.data,
        );
    return data;
  }

  Incident _update(UpdateIncident event) {
    //TODO: Implement call to backend

    var data = this._incidents.update(
          event.data.id,
          (incident) => event.data,
          ifAbsent: () => event.data,
        );
    return data;
  }

  _delete(DeleteIncident event) {
    //TODO: Implement call to backend

    if (this.incidents.remove(event.data.id)) {
      throw "Failed to delete ${event.data.id}";
    }
  }

  IncidentSelected _set(Incident data) {
    this._given = data.id;
    return IncidentSelected(data);
  }

  IncidentUnset _unset() {
    this._given = null;
    return IncidentUnset();
  }

  @override
  void onEvent(IncidentCommand event) {
    print("Command $event");
  }

  @override
  void onTransition(Transition<IncidentCommand, IncidentState> transition) {
    print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    print("Error $error, stacktrace: $stacktrace");
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<T> extends Equatable {
  final T data;

  IncidentCommand(this.data) : super();
}

class CreateIncident extends IncidentCommand<Incident> {
  final bool selected;
  CreateIncident(Incident data, {this.selected = true}) : super(data);

  @override
  String toString() => 'CreateIncident';
}

class UpdateIncident extends IncidentCommand<Incident> {
  final bool selected;
  UpdateIncident(Incident data, {this.selected = true}) : super(data);

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

/// ---------------------
/// States
/// ---------------------
abstract class IncidentState<T> extends Equatable {
  final T data;

  IncidentState(this.data, [props = const []]) : super([data, ...props]);

  isUnset() => this.data is IncidentUnset;
  isError() => this.data is IncidentError;
  isSelected() => this.data is IncidentSelected;
}

class IncidentUnset extends IncidentState<Incident> {
  IncidentUnset() : super(null);

  @override
  String toString() => 'IncidentUnset';
}

class IncidentCreated extends IncidentState<Incident> {
  final bool selected;
  IncidentCreated(Incident data, {this.selected = true}) : super(data, selected);

  @override
  String toString() => 'IncidentCreated';
}

class IncidentUpdated extends IncidentState<Incident> {
  final bool selected;
  IncidentUpdated(Incident data, {this.selected = true}) : super(data, selected);

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

/// Incident error state
class IncidentError extends IncidentState<Object> {
  final StackTrace stackTrace;
  IncidentError(Object error, this.stackTrace) : super(error, stackTrace);

  @override
  String toString() => 'IncidentError';
}
