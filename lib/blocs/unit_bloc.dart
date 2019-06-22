import 'dart:collection';

import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends Bloc<UnitCommand, UnitState> {
  final UnitService service;

  final LinkedHashMap<String, Unit> _units = LinkedHashMap();

  UnitBloc(this.service);

  @override
  UnitState get initialState => UnitsEmpty();

  /// Check if [units] is empty
  bool get isEmpty => units.isEmpty;

  /// Get units
  List<Unit> get units => UnmodifiableListView<Unit>(_units.values);

  /// Initialize if empty
  UnitBloc init(UnitCallback onInit) {
    if (isEmpty) {
      fetch().then((_) => onInit(() {}));
    }
    return this;
  }

  /// Create given unit
  UnitBloc create(Unit unit) {
    dispatch(CreateUnit(unit));
    return this;
  }

  /// Update given unit
  UnitBloc update(Unit unit) {
    dispatch(UpdateUnit(unit));
    return this;
  }

  /// Fetch units from [service]
  Future<List<Unit>> fetch() async {
    dispatch(ClearUnits(_units.keys.toList()));
    var units = await service.fetch();
    dispatch(LoadUnits(units));
    return UnmodifiableListView<Unit>(units);
  }

  @override
  Stream<UnitState> mapEventToState(UnitCommand command) async* {
    if (command is LoadUnits) {
      List<String> ids = _load(command.data);
      yield UnitsLoaded(ids);
    } else if (command is CreateUnit) {
      Unit data = await _create(command);
      yield UnitCreated(data);
    } else if (command is UpdateUnit) {
      Unit data = await _update(command);
      yield UnitUpdated(data);
    } else if (command is DeleteUnit) {
      Unit data = await _delete(command);
      yield UnitDeleted(data);
    } else if (command is ClearUnits) {
      List<Unit> units = _clear(command);
      yield UnitsCleared(units);
    } else if (command is RaiseUnitError) {
      yield command.data;
    } else {
      yield UnitError("Unsupported $command");
    }
  }

  List<String> _load(List<Unit> units) {
    //TODO: Implement call to backend

    _units.addEntries(units.map(
      (unit) => MapEntry(unit.id, unit),
    ));
    return _units.keys.toList();
  }

  Future<Unit> _create(CreateUnit event) async {
    //TODO: Implement call to backend

    var data = _units.putIfAbsent(
      event.data.id,
      () => event.data,
    );
    return Future.value(data);
  }

  Future<Unit> _update(UpdateUnit event) async {
    //TODO: Implement call to backend

    var data = _units.update(
      event.data.id,
      (unit) => event.data,
      ifAbsent: () => event.data,
    );
    return Future.value(data);
  }

  Future<Unit> _delete(DeleteUnit event) {
    //TODO: Implement call to backend

    if (this.units.remove(event.data.id)) {
      throw "Failed to delete unit ${event.data.id}";
    }
    return Future.value(event.data);
  }

  List<Unit> _clear(ClearUnits command) {
    List<Unit> cleared = [];
    command.data.forEach((id) => {if (_units.containsKey(id)) cleared.add(_units.remove(id))});
    return cleared;
  }

  @override
  void onEvent(UnitCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<UnitCommand, UnitState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseUnitError(UnitError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UnitCommand<T> extends Equatable {
  final T data;

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
