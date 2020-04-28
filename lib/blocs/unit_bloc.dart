import 'dart:async';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/repositories/unit_repository.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/utils/data_utils.dart';

import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends Bloc<UnitCommand, UnitState> {
  UnitBloc(
    this.repo,
    this.incidentBloc,
    this.personnelBloc,
  ) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    _subscriptions
      ..add(incidentBloc.listen(
        _processIncidentEvent,
      ))
      ..add(personnelBloc.listen(
        _processPersonnelEvent,
      ));
  }

  void _processIncidentEvent(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty != null) {
        // Clear out current tracking upon states given below
        if (state.shouldUnload(iuuid) && repo.isReady) {
          add(UnloadUnits(iuuid));
        } else if (state.isSelected()) {
          add(LoadUnits(state.data.uuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  void _processPersonnelEvent(PersonnelState state) {
    try {
      if (state.isUpdated()) {
        final event = state as PersonnelUpdated;
        final unit = repo.findAndReplace(event.data);
        if (unit != null) {
          _dispatch(
            _InternalChange(unit),
          );
        }
      } else if (state.isDeleted()) {
        final event = state as PersonnelDeleted;
        final unit = repo.findAndRemove(event.data);
        if (unit != null) {
          _dispatch(
            _InternalChange(unit),
          );
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  /// Subscriptions released on [close]
  List<StreamSubscription> _subscriptions = [];

  /// Get [IncidentBloc]
  final IncidentBloc incidentBloc;

  /// Get [PersonnelBloc]
  final PersonnelBloc personnelBloc;

  /// Get [UnitRepository]
  final UnitRepository repo;

  /// Get [UnitService]
  UnitService get service => repo.service;

  /// [Incident] that manages given [units]
  String get iuuid => repo.iuuid;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.iuuid == null;

  /// Get units
  Map<String, Unit> get units => repo.map;

  @override
  UnitState get initialState => UnitsEmpty();

  /// Stream of changes on given unit
  Stream<Unit> onChanged(Unit unit) => where(
        (state) =>
            (state is UnitUpdated && state.data.uuid == unit.uuid) ||
            (state is UnitsLoaded && state.data.contains(unit.uuid)),
      ).map((state) => state is UnitsLoaded ? repo[unit.uuid] : state.data);

  /// Get count
  int count({List<UnitStatus> exclude: const [UnitStatus.Retired]}) => repo.count(exclude: exclude);

  /// Find unit from personnel
  Iterable<Unit> find(
    Personnel personnel, {
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      repo.find(personnel, exclude: exclude);

  /// Get next available number
  int nextAvailableNumber(bool reuse) => repo.nextAvailableNumber(reuse);

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
        "number": number,
        "type": enumName(type),
        "status": enumName(UnitStatus.Mobilized),
        "callsign": toCallsign(department, offset + number),
      });
    }
    return null;
  }

  void _assertState() {
    if (incidentBloc.isUnset) {
      throw UnitError(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'UnitBloc.load()'",
      );
    }
  }

  /// Fetch units from [service]
  Future<List<Unit>> load() async {
    _assertState();
    return _dispatch<List<Unit>>(
      LoadUnits(iuuid ?? incidentBloc.selected.uuid),
    );
  }

  /// Create given unit
  Future<Unit> create(Unit unit) {
    _assertState();
    return _dispatch<Unit>(
      CreateUnit(iuuid ?? incidentBloc.selected.uuid, unit),
    );
  }

  /// Update given unit
  Future<Unit> update(Unit unit) {
    _assertState();
    return _dispatch<Unit>(
      UpdateUnit(unit),
    );
  }

  /// Delete given unit
  Future<Unit> delete(Unit unit) {
    _assertState();
    return _dispatch<Unit>(
      DeleteUnit(unit),
    );
  }

  /// Unload [units] from local storage
  Future<List<Unit>> unload() {
    _assertState();
    return _dispatch<List<Unit>>(
      UnloadUnits(iuuid),
    );
  }

  @override
  Stream<UnitState> mapEventToState(UnitCommand command) async* {
    if (command is LoadUnits) {
      yield await _load(command);
    } else if (command is CreateUnit) {
      yield await _create(command);
    } else if (command is UpdateUnit) {
      yield await _update(command);
    } else if (command is DeleteUnit) {
      yield await _delete(command);
    } else if (command is UnloadUnits) {
      yield await _unload(command);
    } else if (command is _InternalChange) {
      yield await _process(command);
    } else if (command is RaiseUnitError) {
      yield _toError(
        command,
        command.data,
      );
    } else {
      yield _toError(
        command,
        UnitError(
          "Unsupported $command",
          stackTrace: StackTrace.current,
        ),
      );
    }
  }

  Future<UnitState> _load(LoadUnits command) async {
    var devices = await repo.load(command.data);
    return _toOK(
      command,
      UnitsLoaded(repo.keys),
      result: devices,
    );
  }

  Future<UnitState> _create(CreateUnit command) async {
    var device = await repo.create(command.iuuid, command.data);
    return _toOK(
      command,
      UnitCreated(device),
      result: device,
    );
  }

  Future<UnitState> _update(UpdateUnit command) async {
    final device = await repo.update(command.data);
    return _toOK(
      command,
      UnitUpdated(device),
      result: device,
    );
  }

  Future<UnitState> _delete(DeleteUnit command) async {
    final device = await repo.delete(command.data.uuid);
    return _toOK(
      command,
      UnitDeleted(device),
      result: device,
    );
  }

  Future<UnitState> _unload(UnloadUnits command) async {
    final devices = await repo.unload();
    return _toOK(
      command,
      UnitsUnloaded(devices),
      result: devices,
    );
  }

  Future<UnitState> _process(_InternalChange command) async {
    final device = await repo.patch(command.data);
    return _toOK(
      command,
      UnitUpdated(device),
      result: device,
    );
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(UnitCommand<Object, T> command) {
    add(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  UnitState _toOK<T>(UnitCommand event, UnitState state, {T result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  UnitState _toError(UnitCommand event, Object error) {
    final object = error is UnitError
        ? error
        : UnitError(
            error,
            stackTrace: StackTrace.current,
          );
    event.callback.completeError(
      error,
      object.stackTrace ?? StackTrace.current,
    );
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscriptions.isNotEmpty) {
      add(RaiseUnitError(UnitError(
        error,
        stackTrace: stacktrace,
      )));
    } else {
      throw UnitBlocException(
        error,
        state,
        stackTrace: stacktrace,
      );
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UnitCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();

  UnitCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadUnits extends UnitCommand<String, List<Unit>> {
  LoadUnits(String iuuid) : super(iuuid);

  @override
  String toString() => 'LoadUnits {iuuid: $data}';
}

class CreateUnit extends UnitCommand<Unit, Unit> {
  String iuuid;
  CreateUnit(this.iuuid, Unit data) : super(data);

  @override
  String toString() => 'CreateUnit {iuuid: $iuuid, unit: $data}';
}

class UpdateUnit extends UnitCommand<Unit, Unit> {
  UpdateUnit(Unit data) : super(data);

  @override
  String toString() => 'UpdateUnit {unit: $data}';
}

class DeleteUnit extends UnitCommand<Unit, Unit> {
  DeleteUnit(Unit data) : super(data);

  @override
  String toString() => 'DeleteUnit {unit: $data}';
}

class UnloadUnits extends UnitCommand<String, List<Unit>> {
  UnloadUnits(String iuuid) : super(iuuid);

  @override
  String toString() => 'UnloadUnits {iuuid: $data}';
}

class _InternalChange extends UnitCommand<Unit, Unit> {
  _InternalChange(Unit data) : super(data);

  @override
  String toString() => '_InternalChange {unit: $data}';
}

class RaiseUnitError extends UnitCommand<UnitError, UnitError> {
  RaiseUnitError(data) : super(data);

  @override
  String toString() => 'RaiseUnitError {error: $data}';
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
  isUnloaded() => this is UnitsUnloaded;
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

class UnitsUnloaded extends UnitState<List<Unit>> {
  UnitsUnloaded(List<Unit> units) : super(units);

  @override
  String toString() => 'UnitsUnloaded';
}

/// ---------------------
/// Error States
/// ---------------------

class UnitError extends UnitState<Object> {
  final StackTrace stackTrace;
  UnitError(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => 'UnitError {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class UnitBlocException implements Exception {
  UnitBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final UnitState state;
  final StackTrace stackTrace;
  final Object command;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
