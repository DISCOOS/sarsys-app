import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends Bloc<UnitCommand, UnitState> {
  final UnitService service;
  final IncidentBloc incidentBloc;

  final LinkedHashMap<String, Unit> _units = LinkedHashMap();

  // only set once to prevent reentrant error loop
  StreamSubscription _subscription;

  UnitBloc(this.service, this.incidentBloc) {
    assert(this.service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    _subscription = incidentBloc.state.listen(_init);
  }

  void _init(IncidentState state) {
    if (_subscription != null) {
      if (state.isUnset() || state.isCreated() || state.isDeleted())
        dispatch(ClearUnits(_units.keys.toList()));
      else if (state.isSelected()) _fetch(state.data.id);
    }
  }

  @override
  UnitState get initialState => UnitsEmpty();

  /// Check if [units] is empty
  bool get isEmpty => units.isEmpty;

  /// Get count
  int get count => _units.length;

  /// Get units
  Map<String, Unit> get units => UnmodifiableMapView<String, Unit>(_units);

  /// Create given unit
  Future<Unit> create(Unit unit) {
    return _dispatch<Unit>(CreateUnit(unit));
  }

  /// Update given unit
  Future<void> update(Unit unit) {
    return _dispatch<void>(UpdateUnit(unit));
  }

  /// Delete given unit
  Future<void> delete(Unit unit) {
    return _dispatch<void>(DeleteUnit(unit));
  }

  /// Fetch units from [service]
  Future<List<Unit>> fetch() async {
    if (incidentBloc.isUnset) {
      return Future.error(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'UnitBloc.fetch()'",
      );
    }
    return _fetch(incidentBloc.current.id);
  }

  Future<List<Unit>> _fetch(String id) async {
    var response = await service.fetch(id);
    if (response.is200) {
      dispatch(ClearUnits(_units.keys.toList()));
      return _dispatch(LoadUnits(response.body));
    }
    dispatch(RaiseUnitError(response));
    return Future.error(response);
  }

  @override
  Stream<UnitState> mapEventToState(UnitCommand command) async* {
    if (command is LoadUnits) {
      yield _load(command.data);
    } else if (command is CreateUnit) {
      yield await _create(command);
    } else if (command is UpdateUnit) {
      yield await _update(command);
    } else if (command is DeleteUnit) {
      yield await _delete(command);
    } else if (command is ClearUnits) {
      yield _clear(command);
    } else if (command is RaiseUnitError) {
      yield command.data;
    } else {
      yield UnitError("Unsupported $command");
    }
  }

  UnitsLoaded _load(List<Unit> units) {
    _units.addEntries(units.map(
      (unit) => MapEntry(unit.id, unit),
    ));
    return UnitsLoaded(_units.keys.toList());
  }

  Future<UnitState> _create(CreateUnit event) async {
    var response = await service.create(incidentBloc.current.id, event.data);
    if (response.is200) {
      var unit = _units.putIfAbsent(
        response.body.id,
        () => response.body,
      );
      return _toOK(event, UnitCreated(unit), result: unit);
    }
    return _toError(event, response);
  }

  Future<UnitState> _update(UpdateUnit event) async {
    var response = await service.update(event.data);
    if (response.is204) {
      _units.update(
        event.data.id,
        (_) => event.data,
        ifAbsent: () => event.data,
      );
      // If state is Retired any tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, UnitUpdated(event.data));
    }
    return _toError(event, response);
  }

  Future<UnitState> _delete(DeleteUnit event) async {
    var response = await service.delete(event.data);
    if (response.is204) {
      if (_units.remove(event.data.id) == null) {
        return _toError(event, "Failed to delete unit $event, not found locally");
      }
      // Any tracking is removed by listening to this event in TrackingBloc
      return _toOK(event, UnitDeleted(event.data));
    }
    return _toError(event, response);
  }

  UnitState _clear(ClearUnits command) {
    List<Unit> cleared = [];
    command.data.forEach((id) => {if (_units.containsKey(id)) cleared.add(_units.remove(id))});
    return UnitsCleared(cleared);
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(UnitCommand<T> command) {
    dispatch(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  Future<UnitState> _toOK(UnitCommand event, UnitState state, {Unit result}) async {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  Future<UnitState> _toError(UnitCommand event, Object response) async {
    final error = UnitError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscription != null) {
      dispatch(RaiseUnitError(UnitError(error, trace: stacktrace)));
    } else {
      throw "Bad state: UnitBloc is disposed. Unexpected ${UnitError(error, trace: stacktrace)}";
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
abstract class UnitCommand<T> extends Equatable {
  final T data;
  final Completer<T> callback = Completer();

  UnitCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadUnits extends UnitCommand<List<Unit>> {
  LoadUnits(List<Unit> data) : super(data);

  @override
  String toString() => 'LoadUnits';
}

class CreateUnit extends UnitCommand<Unit> {
  CreateUnit(Unit data) : super(data);

  @override
  String toString() => 'CreateUnit';
}

class UpdateUnit extends UnitCommand<Unit> {
  UpdateUnit(Unit data) : super(data);

  @override
  String toString() => 'UpdateUnit';
}

class DeleteUnit extends UnitCommand<Unit> {
  DeleteUnit(Unit data) : super(data);

  @override
  String toString() => 'DeleteUnit';
}

class ClearUnits extends UnitCommand<List<String>> {
  ClearUnits(List<String> data) : super(data);

  @override
  String toString() => 'ClearUnits';
}

class RaiseUnitError extends UnitCommand<UnitError> {
  RaiseUnitError(data) : super(data);

  @override
  String toString() => 'RaiseUnitError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class UnitState<T> extends Equatable {
  final T data;

  UnitState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is UnitsEmpty;
  isLoaded() => this is UnitsLoaded;
  isCreated() => this is UnitCreated;
  isUpdated() => this is UnitUpdated;
  isDeleted() => this is UnitDeleted;
  isCleared() => this is UnitsCleared;
  isException() => this is UnitException;
  isError() => this is UnitError;
}

class UnitsEmpty extends UnitState<Null> {
  UnitsEmpty() : super(null);

  @override
  String toString() => 'UnitsEmpty';
}

class UnitsLoaded extends UnitState<List<String>> {
  UnitsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'UnitsLoaded';
}

class UnitCreated extends UnitState<Unit> {
  UnitCreated(Unit data) : super(data);

  @override
  String toString() => 'UnitCreated';
}

class UnitUpdated extends UnitState<Unit> {
  UnitUpdated(Unit data) : super(data);

  @override
  String toString() => 'UnitUpdated';
}

class UnitDeleted extends UnitState<Unit> {
  UnitDeleted(Unit data) : super(data);

  @override
  String toString() => 'UnitDeleted';
}

class UnitsCleared extends UnitState<List<Unit>> {
  UnitsCleared(List<Unit> units) : super(units);

  @override
  String toString() => 'UnitsCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class UnitException extends UnitState<Object> {
  final StackTrace trace;
  UnitException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'UnitException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class UnitError extends UnitException {
  final StackTrace trace;
  UnitError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'UnitError {data: $data}';
}
