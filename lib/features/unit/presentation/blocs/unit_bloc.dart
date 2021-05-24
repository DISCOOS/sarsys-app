import 'dart:async';
import 'dart:math';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart' as action;
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:bloc/bloc.dart';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:uuid/uuid.dart';

import 'unit_bloc_commands.dart';
import 'unit_bloc_states.dart';

export 'unit_bloc_commands.dart';
export 'unit_bloc_states.dart';

typedef void UnitCallback(VoidCallback fn);

class UnitBloc extends StatefulBloc<UnitCommand, UnitState, UnitBlocError, String, Unit, UnitService>
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
    this.operationBloc,
    BlocEventBus bus,
  ) : super(UnitsEmpty(), bus: bus) {
    assert(repo != null, "repository can not be null");
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");

    // Load and unload personnels as needed
    subscribe<OperationUpdated>(_processOperationState);
    subscribe<OperationSelected>(_processOperationState);
    subscribe<OperationUnselected>(_processOperationState);
    subscribe<OperationDeleted>(_processOperationState);

    // Remove reference to personnel
    subscribe<PersonnelDeleted>(_processPersonnelDeleted);

    // Notify when device state has changed
    forward(
      (t) => _NotifyRepositoryStateChanged(t),
    );
  }

  /// All repositories
  Iterable<StatefulRepository> get repos => [repo];

  /// Process [OperationState] events
  ///
  /// Invokes [load] and [unload] as needed.
  ///
  void _processOperationState(Bloc bloc, OperationState state) async {
    // Only process local events
    if (isOpen && state.isLocal) {
      final unselected = (bloc as OperationBloc).isUnselected;
      if (state.shouldLoad(ouuid)) {
        await dispatch(LoadUnits(
          (state.data as Operation).uuid,
        ));
        // Could change during load
        if ((bloc as OperationBloc).isSelected && (state is OperationCreated && state.units.isNotEmpty)) {
          action.createUnits(
            bloc: this,
            templates: state.units,
          );
        }
      } else if (isReady && (unselected || state.shouldUnload(ouuid))) {
        await unload();
      }
    }
  }

  void _processPersonnelDeleted(Bloc bloc, PersonnelDeleted state) {
    final puuid = state.data.uuid;
    final units = repo.findPersonnel(puuid);
    if (units.isNotEmpty) {
      for (var unit in units) {
        if (unit.personnels.contains(puuid)) {
          dispatch(
            _toAprioriChange(
              unit.copyWith(
                personnels: unit.personnels.toList()..remove(puuid),
              ),
            ),
          );
        }
      }
    }
  }

  /// Create [_NotifyRepositoryStateChanged] for processing [UnitMessageType.UnitInformationUpdated]
  _HandleMessage _toAprioriChange(Unit unit) => _HandleMessage(
        UnitMessage.updated(unit),
      );

  /// Get [OperationBloc]
  final OperationBloc operationBloc;

  /// Get [UnitRepository]
  final UnitRepository repo;

  /// Get [Unit] from [uuid]
  Unit operator [](String uuid) => repo[uuid];

  /// Get all [Unit]s
  Iterable<Unit> get values => repo.values;

  /// Get [UnitService]
  UnitService get service => repo.service;

  /// Get units
  Map<String, Unit> get units => repo.map;

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

  /// [Operation] that manages given [map]
  String get ouuid => isReady ? repo.ouuid ?? operationBloc.selected?.uuid : null;

  /// Stream of changes on given unit
  Stream<Unit> onChanged(String uuid) => stream
      .where(
        (state) =>
            (state is UnitUpdated && state.data.uuid == uuid) || (state is UnitsLoaded && state.data.contains(uuid)),
      )
      .map((state) => state is UnitsLoaded ? repo[uuid] : state.data);

  /// Get count
  int count({List<UnitStatus> exclude: const [UnitStatus.retired]}) => repo.count(exclude: exclude);

  /// Find units given personnel is assigned to
  Iterable<Unit> findUnitsWithPersonnel(
    String puuid, {
    List<UnitStatus> exclude: const [UnitStatus.retired],
  }) =>
      repo.findPersonnel(puuid, exclude: exclude);

  /// Find [Personnel] not allocated to an [Unit]
  Iterable<Personnel> findAvailablePersonnel(PersonnelRepository personnels) {
    final assigned = repo.values.fold<List<String>>(
      [],
      (personnels, unit) => personnels..addAll(unit.personnels),
    );
    return personnels.values.where(
      (personnel) => !assigned.contains(personnel.uuid),
    );
  }

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

  void _assertData(Unit unit) {
    if (unit?.uuid == null) {
      throw ArgumentError(
        "Unit have no uuid",
      );
    }
    if (unit?.operation?.uuid == null) {
      throw ArgumentError(
        "Unit ${unit.uuid} have no operation uuid",
      );
    }
    if (unit?.operation?.uuid != ouuid) {
      throw ArgumentError(
        "Unit ${unit.uuid} is not mobilized for operation $ouuid",
      );
    }
    TrackingUtils.assertRef(unit);
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
    return dispatch<List<Unit>>(
      UnloadUnits(ouuid),
    );
  }

  @override
  Stream<UnitState> execute(UnitCommand command) async* {
    if (command is LoadUnits) {
      yield* _load(command);
    } else if (command is CreateUnit) {
      yield* _create(command);
    } else if (command is UpdateUnit) {
      yield* _update(command);
    } else if (command is DeleteUnit) {
      yield* _delete(command);
    } else if (command is UnloadUnits) {
      yield await _unload(command);
    } else if (command is _HandleMessage) {
      yield await _process(command);
    } else if (command is _NotifyRepositoryStateChanged) {
      yield _notify(command);
    } else if (command is _NotifyBlocStateChanged) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<UnitState> _load(LoadUnits command) async* {
    // Fetch cached and handle
    // response from remote when ready
    final onRemote = Completer<Iterable<Unit>>();
    var units = await repo.load(
      command.data,
      onRemote: onRemote,
    );
    yield toOK(
      command,
      UnitsLoaded(repo.keys),
      result: units,
    );

    // Notify when states was fetched from remote storage
    onComplete(
      [onRemote.future],
      toState: (_) => UnitsLoaded(
        repo.keys,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Object>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<UnitState> _create(CreateUnit command) async* {
    _assertData(command.data);
    final unit = repo.apply(command.data);
    yield toOK(
      command,
      UnitCreated(
        unit,
        position: command.position,
        devices: command.devices,
      ),
      result: unit,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(unit.uuid)],
      toState: (_) => UnitCreated(
        units[unit.uuid],
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Unit>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<UnitState> _update(UpdateUnit command) async* {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final unit = repo.apply(command.data);

    yield toOK(
      command,
      UnitUpdated(unit, previous),
      result: unit,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(unit.uuid)],
      toState: (_) => UnitUpdated(
        units[unit.uuid],
        previous,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Unit>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<UnitState> _delete(DeleteUnit command) async* {
    _assertData(command.data);
    final onRemote = Completer<Unit>();
    final unit = repo.delete(
      command.data.uuid,
      onResult: onRemote,
    );
    yield toOK(
      command,
      UnitDeleted(unit),
      result: unit,
    );

    // Notify when all states are remote
    onComplete(
      [onRemote.future],
      toState: (_) => UnitDeleted(
        unit,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Unit>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
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

  Future<UnitState> _process(_HandleMessage command) async {
    if (isReady) {
      switch (command.data.type) {
        case UnitMessageType.UnitCreated:
        case UnitMessageType.UnitInformationUpdated:
          final value = UnitModel.fromJson(command.data.state);
          final next = repo.patch(value, isRemote: false).value;
          return command.data.type == UnitMessageType.UnitCreated
              ? UnitCreated(next)
              : UnitUpdated(
                  next,
                  value,
                );
        case UnitMessageType.UnitDeleted:
          final current = repo[command.data.uuid];
          if (current != null) {
            repo.remove(current, isRemote: false);
          }
          return UnitDeleted(current);
        default:
          throw UnitBlocException(
            "Unit message '${enumName(command.data.type)}' not recognized",
            state,
            command: command,
            stackTrace: StackTrace.current,
          );
      }
    }
    return state;
  }

  UnitState _notify(_NotifyRepositoryStateChanged command) {
    final state = command.state;

    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          UnitCreated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );

      case StorageStatus.updated:
        return toOK(
          command,
          UnitUpdated(
            state,
            command.previous,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          UnitDeleted(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
    }
    return toError(
      command,
      'Unknown state status ${command.status}',
      stackTrace: StackTrace.current,
    );
  }

  @override
  UnitBlocError createError(Object error, {StackTrace stackTrace}) => UnitBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}

/// ---------------------
/// Internal commands
/// ---------------------

class _HandleMessage extends UnitCommand<UnitMessage, void> {
  _HandleMessage(UnitMessage data) : super(data);

  @override
  String toString() => '$runtimeType {unit: $data}';
}

class _NotifyRepositoryStateChanged extends UnitCommand<StorageTransition<Unit>, Unit>
    with NotifyRepositoryStateChangedMixin {
  _NotifyRepositoryStateChanged(StorageTransition<Unit> transition) : super(transition);
}

class _NotifyBlocStateChanged<T> extends UnitCommand<UnitState<T>, T>
    with NotifyBlocStateChangedMixin<UnitState<T>, T> {
  _NotifyBlocStateChanged(UnitState<T> state) : super(state);
}
