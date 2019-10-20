import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void PersonnelCallback(VoidCallback fn);

class PersonnelBloc extends Bloc<PersonnelCommand, PersonnelState> {
  final PersonnelService service;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Personnel> _personnel = LinkedHashMap();

  // only set once to prevent reentrant error loop
  StreamSubscription _subscription;

  PersonnelBloc(this.service, this.incidentBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    _subscription = incidentBloc.state.listen(_init);
  }

  void _init(IncidentState state) {
    if (_subscription != null) {
      if (state.isUnset() || state.isCreated() || state.isDeleted())
        dispatch(ClearPersonnels(_personnel.keys.toList()));
      else if (state.isSelected()) _fetch(state.data.id);
    }
  }

  @override
  PersonnelState get initialState => PersonnelsEmpty();

  /// Stream of changes on given Personnel
  Stream<Personnel> changes(Personnel personnel) => state
      .where(
        (state) =>
            (state is PersonnelUpdated && state.data.id == personnel.id) ||
            (state is PersonnelsLoaded && state.data.contains(personnel.id)),
      )
      .map((state) => state is PersonnelsLoaded ? _personnel[personnel.id] : state.data);

  /// Check if [personnel] is empty
  bool get isEmpty => personnel.isEmpty;

  /// Get count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      exclude?.isNotEmpty == false
          ? _personnel.length
          : _personnel.values.where((personnel) => !exclude.contains(personnel.status)).length;

  /// Get personnel
  Map<String, Personnel> get personnel => UnmodifiableMapView<String, Personnel>(_personnel);

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) {
    return _dispatch<Personnel>(CreatePersonnel(personnel));
  }

  /// Update given personnel
  Future<Personnel> update(Personnel personnel) {
    return _dispatch<Personnel>(UpdatePersonnel(personnel));
  }

  /// Delete given personnel
  Future<void> delete(Personnel personnel) {
    return _dispatch<void>(DeletePersonnel(personnel));
  }

  /// Fetch personnel from [service]
  Future<List<Personnel>> fetch() async {
    if (incidentBloc.isUnset) {
      return Future.error(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'PersonnelBloc.fetch()'",
      );
    }
    return _fetch(incidentBloc.current.id);
  }

  Future<List<Personnel>> _fetch(String id) async {
    var response = await service.fetch(id);
    if (response.is200) {
      dispatch(ClearPersonnels(_personnel.keys.toList()));
      return _dispatch(LoadPersonnels(response.body));
    }
    dispatch(RaisePersonnelError(response));
    return Future.error(response);
  }

  @override
  Stream<PersonnelState> mapEventToState(PersonnelCommand command) async* {
    if (command is LoadPersonnels) {
      yield _load(command.data);
    } else if (command is CreatePersonnel) {
      yield await _create(command);
    } else if (command is UpdatePersonnel) {
      yield await _update(command);
    } else if (command is DeletePersonnel) {
      yield await _delete(command);
    } else if (command is ClearPersonnels) {
      yield _clear(command);
    } else if (command is RaisePersonnelError) {
      yield command.data;
    } else {
      yield PersonnelError("Unsupported $command");
    }
  }

  PersonnelsLoaded _load(List<Personnel> personnel) {
    _personnel.addEntries(personnel.map(
      (personnel) => MapEntry(personnel.id, personnel),
    ));
    return PersonnelsLoaded(_personnel.keys.toList());
  }

  Future<PersonnelState> _create(CreatePersonnel event) async {
    var response = await service.create(incidentBloc.current.id, event.data);
    if (response.is200) {
      var personnel = _personnel.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK(event, PersonnelCreated(personnel), result: personnel);
    }
    return _toError(event, response);
  }

  Future<PersonnelState> _update(UpdatePersonnel event) async {
    var response = await service.update(event.data);
    if (response.is204) {
      _personnel.update(
        event.data.id,
        (_) => event.data,
        ifAbsent: () => event.data,
      );
      // If state is Retired any tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, PersonnelUpdated(event.data), result: event.data);
    }
    return _toError(event, response);
  }

  Future<PersonnelState> _delete(DeletePersonnel event) async {
    var response = await service.delete(event.data);
    if (response.is204) {
      if (_personnel.remove(event.data.id) == null) {
        return _toError(event, "Failed to delete Personnel $event, not found locally");
      }
      // Any tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, PersonnelDeleted(event.data));
    }
    return _toError(event, response);
  }

  PersonnelState _clear(ClearPersonnels command) {
    List<Personnel> cleared = [];
    command.data.forEach((id) => {if (_personnel.containsKey(id)) cleared.add(_personnel.remove(id))});
    return PersonnelsCleared(cleared);
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(PersonnelCommand<T> command) {
    dispatch(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  Future<PersonnelState> _toOK(PersonnelCommand event, PersonnelState state, {Personnel result}) async {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  Future<PersonnelState> _toError(PersonnelCommand event, Object response) async {
    final error = PersonnelError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscription != null) {
      dispatch(RaisePersonnelError(PersonnelError(error, trace: stacktrace)));
    } else {
      throw "Bad state: PersonnelBloc is disposed. Unexpected ${PersonnelError(error, trace: stacktrace)}";
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
abstract class PersonnelCommand<T> extends Equatable {
  final T data;
  final Completer<T> callback = Completer();

  PersonnelCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadPersonnels extends PersonnelCommand<List<Personnel>> {
  LoadPersonnels(List<Personnel> data) : super(data);

  @override
  String toString() => 'LoadPersonnels';
}

class CreatePersonnel extends PersonnelCommand<Personnel> {
  CreatePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'CreatePersonnel';
}

class UpdatePersonnel extends PersonnelCommand<Personnel> {
  UpdatePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'UpdatePersonnel';
}

class DeletePersonnel extends PersonnelCommand<Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'DeletePersonnel';
}

class ClearPersonnels extends PersonnelCommand<List<String>> {
  ClearPersonnels(List<String> data) : super(data);

  @override
  String toString() => 'ClearPersonnels';
}

class RaisePersonnelError extends PersonnelCommand<PersonnelError> {
  RaisePersonnelError(data) : super(data);

  @override
  String toString() => 'RaisePersonnelError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class PersonnelState<T> extends Equatable {
  final T data;

  PersonnelState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is PersonnelsEmpty;
  isLoaded() => this is PersonnelsLoaded;
  isCreated() => this is PersonnelCreated;
  isUpdated() => this is PersonnelUpdated;
  isDeleted() => this is PersonnelDeleted;
  isCleared() => this is PersonnelsCleared;
  isException() => this is PersonnelException;
  isError() => this is PersonnelError;
}

class PersonnelsEmpty extends PersonnelState<Null> {
  PersonnelsEmpty() : super(null);

  @override
  String toString() => 'PersonnelsEmpty';
}

class PersonnelsLoaded extends PersonnelState<List<String>> {
  PersonnelsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'PersonnelsLoaded';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelCreated';
}

class PersonnelUpdated extends PersonnelState<Personnel> {
  PersonnelUpdated(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelUpdated';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelDeleted';
}

class PersonnelsCleared extends PersonnelState<List<Personnel>> {
  PersonnelsCleared(List<Personnel> personnel) : super(personnel);

  @override
  String toString() => 'PersonnelsCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class PersonnelException extends PersonnelState<Object> {
  final StackTrace trace;
  PersonnelException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'PersonnelException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class PersonnelError extends PersonnelException {
  final StackTrace trace;
  PersonnelError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'PersonnelError {data: $data}';
}
