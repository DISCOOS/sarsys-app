import 'dart:async';
import 'dart:math';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/tracking_utils.dart';

import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:uuid/uuid.dart';

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends BaseBloc<UnitCommand, UnitState, UnitBlocError>
    with
        LoadableBloc<List<Unit>>,
        CreatableBloc<Unit>,
        UpdatableBloc<Unit>,
        DeletableBloc<Unit>,
        UnloadableBloc<List<Unit>> {
  ///
  /// Default constructor
  ///
  UnitBloc(
    this.repo,
    BlocEventBus bus,
    this.operationBloc,
    this.personnelBloc,
  ) : super(bus: bus) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");

    registerStreamSubscription(operationBloc.listen(
      // 1) Load and unloads units as needed
      // 2) Creates units from templates if give in IncidentCreated
      _processIncidentState,
    ));

    registerStreamSubscription(personnelBloc.listen(
      // Keeps local Personnel instances in sync
      // TODO: Replace with direct lookup instead
      _processPersonnelState,
    ));
  }

  void _processIncidentState(OperationState state) async {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad(ouuid)) {
          await dispatch(LoadUnits((state.data as Operation).uuid));
          if (state is OperationCreated) {
            if (state.units.isNotEmpty) {
              createUnits(
                bloc: this,
                templates: state.units,
              );
            }
          }
        } else if (state.shouldUnload(ouuid) && repo.isReady) {
          dispatch(UnloadUnits(ouuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  void _processPersonnelState(PersonnelState state) {
    try {
      if (state.isUpdated()) {
        final event = state as PersonnelUpdated;
        final unit = repo.findAndReplace(event.data);
        if (unit != null) {
          dispatch(
            _InternalChange(unit),
          );
        }
      } else if (state.isDeleted()) {
        final event = state as PersonnelDeleted;
        final unit = repo.findAndRemove(event.data);
        if (unit != null) {
          dispatch(
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

  /// Get [OperationBloc]
  final OperationBloc operationBloc;

  /// Get [PersonnelBloc]
  final PersonnelBloc personnelBloc;

  /// Get [UnitRepository]
  final UnitRepository repo;

  /// Get [Unit] from [uuid]
  Unit operator [](String uuid) => repo[uuid];

  /// Get [UnitService]
  UnitService get service => repo.service;

  /// [Incident] that manages given [units]
  String get ouuid => repo.ouuid;

  /// Check if [Incident.uuid] is set
  bool get isSet => repo.ouuid != null;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.ouuid == null;

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
  int count({List<UnitStatus> exclude: const [UnitStatus.retired]}) => repo.count(exclude: exclude);

  /// Find unit from personnel
  Iterable<Unit> find(
    Personnel personnel, {
    List<UnitStatus> exclude: const [UnitStatus.retired],
  }) =>
      repo.find(personnel, exclude: exclude);

  /// Get next available number
  int nextAvailableNumber(UnitType type, {bool reuse = true}) => repo.nextAvailableNumber(type, reuse: reuse);

  /// Creating a new 'Unit' instance from template string
  Unit fromTemplate(String department, String template, {int count}) {
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

      return UnitModel.fromJson({
        "uuid": Uuid().v4(),
        "number": count ?? number,
        "type": enumName(type),
        "status": enumName(UnitStatus.mobilized),
        "callsign": toCallsign(type, department, number),
      });
    }
    return null;
  }

  void _assertState() {
    if (operationBloc.isUnselected) {
      throw UnitBlocError(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'UnitBloc.load()'",
      );
    }
  }

  void _assertData(Unit data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Unit have no uuid",
      );
    }
    TrackingUtils.assertRef(data);
  }

  /// Fetch units from [service]
  Future<List<Unit>> load() async {
    _assertState();
    return dispatch<List<Unit>>(
      LoadUnits(ouuid ?? operationBloc.selected.uuid),
    );
  }

  /// Create given unit
  Future<Unit> create(
    Unit unit, {
    Position position,
    List<Device> devices,
  }) {
    _assertState();
    return dispatch<Unit>(
      CreateUnit(
        ouuid ?? operationBloc.selected.uuid,
        unit.copyWith(
          // Units should contain a tracking reference when
          // they are created. [TrackingBloc] will use this
          // reference to create a [Tracking] instance which the
          // backend will create apriori using the same uuid.
          // This allows for offline creation of tracking objects
          // in apps resulting in a better user experience
          tracking: TrackingUtils.ensureRef(unit),
        ),
        devices: devices,
        position: position,
      ),
    );
  }

  /// Update given unit
  Future<Unit> update(Unit unit) {
    _assertState();
    return dispatch<Unit>(
      UpdateUnit(unit),
    );
  }

  /// Delete given unit
  Future<Unit> delete(String uuid) {
    _assertState();
    return dispatch<Unit>(
      DeleteUnit(repo[uuid]),
    );
  }

  /// Unload [units] from local storage
  Future<List<Unit>> unload() {
    _assertState();
    return dispatch<List<Unit>>(
      UnloadUnits(ouuid),
    );
  }

  @override
  Stream<UnitState> execute(UnitCommand command) async* {
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
    } else {
      yield toUnsupported(command);
    }
  }

  Future<UnitState> _load(LoadUnits command) async {
    var units = await repo.load(command.data);
    return toOK(
      command,
      UnitsLoaded(repo.keys),
      result: units,
    );
  }

  Future<UnitState> _create(CreateUnit command) async {
    _assertData(command.data);
    var unit = await repo.create(command.ouuid, command.data);
    return toOK(
      command,
      UnitCreated(
        unit,
        position: command.position,
        devices: command.devices,
      ),
      result: unit,
    );
  }

  Future<UnitState> _update(UpdateUnit command) async {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final unit = await repo.update(command.data);
    return toOK(
      command,
      UnitUpdated(unit, previous),
      result: unit,
    );
  }

  Future<UnitState> _delete(DeleteUnit command) async {
    _assertData(command.data);
    final unit = await repo.delete(command.data.uuid);
    return toOK(
      command,
      UnitDeleted(unit),
      result: unit,
    );
  }

  Future<UnitState> _unload(UnloadUnits command) async {
    final units = await repo.close();
    return toOK(
      command,
      UnitsUnloaded(units),
      result: units,
    );
  }

  Future<UnitState> _process(_InternalChange command) async {
    final previous = repo[command.data.uuid];
    final state = repo.replace(command.data.uuid, command.data);
    return toOK(
      command,
      UnitUpdated(state.value, previous),
      result: state.value,
    );
  }

  @override
  UnitBlocError createError(Object error, {StackTrace stackTrace}) => UnitBlocError(
        error,
        stackTrace: StackTrace.current,
      );

  @override
  Future<void> close() async {
    await repo.dispose();
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UnitCommand<S, T> extends BlocCommand<S, T> {
  UnitCommand(S data, [props = const []]) : super(data, props);
}

class LoadUnits extends UnitCommand<String, List<Unit>> {
  LoadUnits(String ouuid) : super(ouuid);

  @override
  String toString() => 'LoadUnits {ouuid: $data}';
}

class CreateUnit extends UnitCommand<Unit, Unit> {
  final String ouuid;
  final Position position;
  final List<Device> devices;

  CreateUnit(
    this.ouuid,
    Unit data, {
    this.position,
    this.devices,
  }) : super(data, [ouuid, position, devices]);

  @override
  String toString() => 'CreateUnit {ouuid: $ouuid, unit: $data, '
      'position: $position, devices: $devices}';
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
  UnloadUnits(String ouuid) : super(ouuid);

  @override
  String toString() => 'UnloadUnits {ouuid: $data}';
}

class _InternalChange extends UnitCommand<Unit, Unit> {
  _InternalChange(Unit data) : super(data);

  @override
  String toString() => '_InternalChange {unit: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class UnitState<T> extends BlocEvent<T> {
  UnitState(
    Object data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, stackTrace: stackTrace, props: props);

  bool isError() => this is UnitBlocError;
  bool isEmpty() => this is UnitsEmpty;
  bool isLoaded() => this is UnitsLoaded;
  bool isCreated() => this is UnitCreated;
  bool isUpdated() => this is UnitUpdated;
  bool isDeleted() => this is UnitDeleted;
  bool isUnloaded() => this is UnitsUnloaded;

  bool isStatusChanged() => false;
  bool isTracked() => (data is Unit) ? (data as Unit).tracking?.uuid != null : false;
  bool isRetired() => (data is Unit) ? (data as Unit).status == UnitStatus.retired : false;
}

class UnitsEmpty extends UnitState<Null> {
  UnitsEmpty() : super(null);

  @override
  String toString() => 'UnitsEmpty';
}

class UnitsLoaded extends UnitState<List<String>> {
  UnitsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'UnitsLoaded {units: $data}';
}

class UnitCreated extends UnitState<Unit> {
  final Position position;
  final List<Device> devices;
  UnitCreated(
    Unit data, {
    this.position,
    this.devices,
  }) : super(data, props: [position, devices]);

  @override
  String toString() => 'UnitCreated {unit: $data, '
      'position: $position, devices: $devices}';
}

class UnitUpdated extends UnitState<Unit> {
  final Unit previous;
  UnitUpdated(Unit data, this.previous) : super(data);

  @override
  bool isStatusChanged() => data.status != previous.status;

  @override
  String toString() => 'UnitUpdated {unit: $data, previous: $previous}';
}

class UnitDeleted extends UnitState<Unit> {
  UnitDeleted(Unit data) : super(data);

  @override
  String toString() => 'UnitDeleted {unit: $data}';
}

class UnitsUnloaded extends UnitState<List<Unit>> {
  UnitsUnloaded(List<Unit> units) : super(units);

  @override
  String toString() => 'UnitsUnloaded {units: $data}';
}

/// ---------------------
/// Error States
/// ---------------------

class UnitBlocError extends UnitState<Object> {
  UnitBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
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
