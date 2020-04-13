import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends Bloc<UnitCommand, UnitState> {
  final UnitService service;
  final IncidentBloc incidentBloc;
  final PersonnelBloc personnelBloc;

  final LinkedHashMap<String, Unit> _units = LinkedHashMap();

  // only set once to prevent reentrant error loop
  List<StreamSubscription> _subscriptions = [];

  UnitBloc(
    this.service,
    this.incidentBloc,
    this.personnelBloc,
  ) {
    assert(this.service != null, "service can not be null");
    assert(this.incidentBloc != null, "incidentBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    _subscriptions..add(incidentBloc.state.listen(_init))..add(personnelBloc.state.listen(_handlePersonnel));
  }

  void _init(IncidentState state) {
    if (_subscriptions.isNotEmpty != null) {
      // Clear out current tracking upon states given below
      if (state.isUnset() ||
          state.isCreated() ||
          state.isDeleted() ||
          (state.isUpdated() &&
              [
                IncidentStatus.Cancelled,
                IncidentStatus.Resolved,
              ].contains((state as IncidentUpdated).data.status))) {
        // TODO: Mark as internal event, no message from units service expected
        dispatch(ClearUnits(_units.keys.toList()));
      } else if (state.isSelected()) {
        _fetch(state.data.uuid);
      }
    }
  }

  void _handlePersonnel(PersonnelState state) {
    if (state.isUpdated()) {
      final event = state as PersonnelUpdated;
      final unit = _units.values.firstWhere(
        (unit) => unit.personnel?.map((personnel) => personnel.id)?.contains(event.data.id),
        orElse: () => null,
      );
      // Update personnel
      if (unit != null) {
        final personnel = unit.personnel.toList()
          ..removeWhere((personnel) => personnel.id == event.data.id)
          ..add(event.data);
        _dispatch(_InternalChange(unit.cloneWith(personnel: personnel)));
      }
    } else if (state.isDeleted()) {
      final event = state as PersonnelDeleted;
      final unit = _units.values.firstWhere(
        (unit) => unit.personnel?.map((personnel) => personnel.id)?.contains(event.data.id),
        orElse: () => null,
      );
      // Remove personnel?
      if (unit != null) {
        final personnel = unit.personnel.toList()..removeWhere((personnel) => personnel.id == event.data.id);
        _dispatch(_InternalChange(unit.cloneWith(personnel: personnel)));
      }
    }
  }

  @override
  UnitState get initialState => UnitsEmpty();

  /// Stream of changes on given unit
  Stream<Unit> changes(Unit unit) => state
      .where(
        (state) =>
            (state is UnitUpdated && state.data.id == unit.id) ||
            (state is UnitsLoaded && state.data.contains(unit.id)),
      )
      .map((state) => state is UnitsLoaded ? _units[unit.id] : state.data);

  /// Check if [units] is empty
  bool get isEmpty => units.isEmpty;

  /// Get count
  int count({
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      exclude?.isNotEmpty == false
          ? _units.length
          : _units.values.where((unit) => !exclude.contains(unit.status)).length;

  /// Get units
  Map<String, Unit> get units => UnmodifiableMapView<String, Unit>(_units);

  /// Creating a new 'Unit' instance from template string
  Unit fromTemplate(String department, String template, {int offset = 20}) {
    final type = UnitType.values.firstWhere(
      (type) {
        final name = translateUnitType(type).toLowerCase();
        final match = template.length >= name.length
            ? template.substring(0, min(name.length, template.length))?.trim()
            : template;
        return name.startsWith(match.toLowerCase());
      },
      orElse: () => null,
    );

    if (type != null) {
      final name = translateUnitType(type).toLowerCase();
      final suffix = template.substring(min(name.length, template.length))?.trim();
      final number = int.tryParse(suffix) ?? 1;

      return Unit.fromJson({
        "type": enumName(type),
        "number": number,
        "status": enumName(UnitStatus.Mobilized),
        "callsign": toCallsign(department, offset + number),
      });
    }
    return null;
  }

  /// Get next available number
  int nextAvailableNumber(bool reuse) {
    if (reuse) {
      var prev = 0;
      final numbers = _units.values
          .where((unit) => UnitStatus.Retired != unit.status)
          .map((unit) => unit.number)
          .toList()
            ..sort((n1, n2) => n1.compareTo(n2));
      final candidates = numbers.takeWhile((next) => (next - prev++) == 1).toList();
      return (candidates.length == 0 ? numbers.length : candidates.last) + 1;
    }
    return count(exclude: []) + 1;
  }

  /// Create given unit
  Future<Unit> create(Unit unit) {
    return _dispatch<Unit>(CreateUnit(unit));
  }

  /// Update given unit
  Future<Unit> update(Unit unit) {
    return _dispatch<Unit>(UpdateUnit(unit));
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
    return _fetch(incidentBloc.selected.uuid);
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
    } else if (command is _InternalChange) {
      yield await _internal(command);
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
    var response = await service.create(incidentBloc.selected.uuid, event.data);
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
      return _internal(event);
    }
    return _toError(event, response);
  }

  Future<UnitState> _internal(UnitCommand<Unit> event) {
    _units.update(
      event.data.id,
      (_) => event.data,
      ifAbsent: () => event.data,
    );
    // If state is Retired any tracking is removed by listening to this event in TrackingBloc
    return _toOK(event, UnitUpdated(event.data), result: event.data);
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
    if (_subscriptions.isNotEmpty) {
      dispatch(RaiseUnitError(UnitError(error, trace: stacktrace)));
    } else {
      throw "Bad state: UnitBloc is disposed. Unexpected ${UnitError(error, trace: stacktrace)}";
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

class _InternalChange extends UnitCommand<Unit> {
  _InternalChange(Unit data) : super(data);

  @override
  String toString() => '_InternalChange';
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
