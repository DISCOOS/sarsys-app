import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

class OperationBloc extends BaseBloc<OperationCommand, OperationState, OperationBlocError>
    with
        LoadableBloc<List<Operation>>,
        CreatableBloc<Operation>,
        UpdatableBloc<Operation>,
        DeletableBloc<Operation>,
        UnloadableBloc<List<Operation>>,
        ConnectionAwareBloc {
  ///
  /// Default constructor
  ///
  OperationBloc(this.repo, this.userBloc, BlocEventBus bus) : super(bus: bus) {
    assert(this.userBloc != null, "userBloc can not be null");
    assert(this.repo != null, "operations repository can not be null");
    assert(this.incidents != null, "incidents repository can not be null");
    assert(this.repo.service != null, "operations service can not be null");
    assert(this.incidents.service != null, "incidents service can not be null");

    registerStreamSubscription(userBloc.listen(
      // Load and unload operations as needed
      _processUserState,
    ));
  }

  /// Key suffix for storing
  /// selected [Operation.uuid]
  /// in [Storage.secure] for
  /// each user
  ///
  static const SELECTED_KEY_SUFFIX = 'selected_ouuid';

  /// Get [UserBloc]
  final UserBloc userBloc;

  /// Get [IncidentRepository]
  IncidentRepository get incidents => repo.incidents;

  /// Get [OperationRepository]
  final OperationRepository repo;

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [incidents, repo];

  /// Get [OperationService]
  OperationService get service => repo.service;

  String _ouuid;

  void _processUserState(UserState state) {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad() && !repo.isReady) {
          dispatch(LoadOperations());
        } else if (state.shouldUnload() && repo.isReady) {
          dispatch(UnloadOperations());
        }
      }
    } catch (error, stackTrace) {
      BlocSupervisor.delegate.onError(
        this,
        error,
        stackTrace,
      );
      onError(error, stackTrace);
    }
  }

  @override
  OperationsEmpty get initialState => OperationsEmpty();

  /// Check if an operation is selected
  bool get isSelected => _ouuid != null;

  /// Check if no operation is selected
  bool get isUnselected => _ouuid == null;

  /// Get selected [Operation]
  Operation get selected => repo[_ouuid];

  /// Get [Operation] from uuid
  Operation get(String uuid) => repo[uuid];

  /// Get operations
  List<Operation> get operations => repo.values;

  /// Get operation uuids
  List<String> get ouuids => repo.keys;

  /// Stream of switched between given operations
  Stream<Operation> get onSwitched => where(
        (state) => state is OperationSelected && state.data.uuid != _ouuid,
      ).map((state) => state.data);

  /// Stream of operation changes
  Stream<Operation> onChanged([Operation operation]) => where(
        (state) => _isOn(operation, state) && state.isCreated() || state.isUpdated() || state.isSelected(),
      ).map((state) => state.data);

  bool _isOn(Operation operation, OperationState state) => (operation == null || state.data.uuid == operation.uuid);

  void _assertUuid(Operation data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Operation have no uuid",
      );
    }
  }

  void _assertData(CreateOperation command) {
    _assertUuid(command.data);
    if (command.incident == null) {
      throw ArgumentError(
        "Operation have no incident data",
      );
    }
    if (command.incident?.uuid == null) {
      throw ArgumentError(
        "Incident have no uuid",
      );
    }
    if (command.data?.incident?.uuid != command.incident.uuid) {
      throw ArgumentError(
        "Operation does reference given incident: "
        "expected ${command.incident.uuid}, found ${command.data?.incident?.uuid}",
      );
    }
  }

  /// Fetch operations from [repo]
  Future<List<Operation>> load() async {
    return dispatch(
      LoadOperations(),
    );
  }

  /// Select [Operation] with given [Operation.uuid]
  Future<Operation> select(String uuid) {
    if (emptyAsNull(uuid) == null) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    return dispatch(SelectOperation(uuid));
  }

  /// Unselect [selected]
  Future<Operation> unselect() {
    return dispatch(UnselectOperation());
  }

  /// Create given operation
  Future<Operation> create(
    Operation operation, {
    @required Incident incident,
    bool selected = true,
    List<String> units = const [],
  }) {
    return dispatch<Operation>(CreateOperation(
      operation,
      units: units,
      selected: selected,
      incident: incident,
    ));
  }

  /// Update given operation
  Future<Operation> update(
    Operation operation, {
    bool selected = true,
    Incident incident,
  }) {
    return dispatch(UpdateOperation(
      operation,
      selected: selected,
      incident: incident,
    ));
  }

  /// Delete given operation
  Future<Operation> delete(String uuid) {
    if (isEmptyOrNull(uuid)) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    return dispatch(DeleteOperation(uuid));
  }

  /// Clear all operations
  Future<List<Operation>> unload() {
    return dispatch(UnloadOperations());
  }

  @override
  Stream<OperationState> execute(OperationCommand command) async* {
    if (command is LoadOperations) {
      yield* _load(command);
    } else if (command is CreateOperation) {
      yield* _create(command);
    } else if (command is UpdateOperation) {
      yield* _update(command);
    } else if (command is SelectOperation) {
      yield* _select(command);
    } else if (command is DeleteOperation) {
      yield* _delete(command);
    } else if (command is UnloadOperations) {
      yield* _unload(command);
    } else if (command is UnselectOperation) {
      yield await _unselect(command);
    } else if (command is _StateChange) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<OperationState> _load(LoadOperations command) async* {
    // Get currently selected uuid
    final ouuid = _ouuid;

    // Fetch cached and handle
    // response from remote when ready
    final onIncidents = Completer<Iterable<Incident>>();
    final onOperations = Completer<Iterable<Operation>>();

    // Execute commands
    await incidents.load(
      onRemote: onIncidents,
    );
    final operations = await repo.load(
      onRemote: onOperations,
    );

    // Unselect and reselect
    final unselected = await _unset(clear: true);
    final selected = await _set(
      operations.firstWhere(
        (operation) => ouuid == operation.uuid,
        orElse: () => null,
      ),
    );

    // Complete request
    final loaded = toOK(
      command,
      OperationsLoaded(
        repo.keys,
        incidents: incidents.keys,
      ),
      result: operations,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield loaded;
    if (selected != null) {
      yield selected;
    }

    // Notify when states was fetched from remote storage
    onComplete(
      [
        onIncidents.future,
        onOperations.future,
      ],
      toState: (_) => OperationsLoaded(
        repo.keys,
        isRemote: true,
        incidents: incidents.keys,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _create(CreateOperation command) async* {
    _assertData(command);
    // Execute commands
    await incidents.apply(command.incident);
    final operation = await repo.apply(command.data);
    final unselected = command.selected ? await _unset(clear: true) : null;
    final selected = command.selected ? await _set(operation) : null;
    // Complete request
    final created = toOK(
      command,
      OperationCreated(
        operation,
        units: command.units,
        incident: command.incident,
      ),
      result: operation,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield created;
    if (selected != null) {
      yield selected;
    }

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(operation.uuid)],
      toState: (_) => OperationCreated(
        operation,
        isRemote: true,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _update(UpdateOperation command) async* {
    _assertUuid(command.data);
    // Execute command
    final operation = await repo.apply(command.data);
    if (command.incident != null) {
      await incidents.apply(command.incident);
    }
    final select = command.selected && command.data.uuid != _ouuid;
    final unselected = select ? await _unset(clear: true) : null;
    final selected = select ? await _set(operation) : null;
    final selectionChanged = unselected != selected;
    // Complete request
    final updated = toOK(
      command,
      OperationUpdated(
        operation,
        incident: command.incident,
        selected: command.selected,
      ),
      result: operation,
    );
    // Notify listeners
    if (selectionChanged) {
      if (unselected != null) {
        yield unselected;
      }
    }
    yield updated;
    if (selectionChanged) {
      if (selected != null) {
        yield selected;
      }
    }

    // Notify when all states are remote
    onComplete(
      [
        repo.onRemote(operation.uuid),
        incidents.onRemote(operation.incident.uuid),
      ],
      toState: (_) => OperationUpdated(
        operation,
        isRemote: true,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _delete(DeleteOperation command) async* {
    final selected = this.selected;
    // Execute command
    var operation = await repo.delete(command.data);
    // Unselect if was selected
    final unselected = command.data == _ouuid
        ? await _unset(
            selected: selected,
            clear: true,
          )
        : null;
    // Complete request
    final deleted = toOK(
      command,
      OperationDeleted(operation),
      result: operation,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield deleted;

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(operation.uuid, require: false)],
      toState: (_) => OperationDeleted(
        operation,
        isRemote: true,
      ),
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _unload(UnloadOperations command) async* {
    final selected = this.selected;
    // Execute commands
    await incidents.close();
    List<Operation> operations = await repo.close();
    // Complete request
    final unselected = await _unset(
      selected: selected,
      clear: false,
    );
    final unloaded = toOK(
      command,
      OperationsUnloaded(operations),
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield unloaded;
  }

  Stream<OperationState> _select(SelectOperation command) async* {
    if (repo.containsKey(command.data)) {
      final operation = repo[command.data];
      final unselected = command.data != _ouuid ? await _unset(clear: true) : null;
      final selected = toOK(
        command,
        await _set(repo[command.data]),
        result: operation,
      );
      if (unselected != null) {
        yield unselected;
      }
      if (selected != null) {
        yield selected;
      }
    } else {
      yield toError(
        command,
        OperationBlocError(
          OperationNotFoundBlocException(
            command.data,
            state,
            command: command,
            stackTrace: command.stackTrace,
          ),
          stackTrace: command.stackTrace,
        ),
      );
    }
  }

  Future<OperationSelected> _set(Operation data) async {
    _ouuid = data?.uuid;
    if (_ouuid != null) {
      await Storage.writeUserValue(
        userBloc.user,
        suffix: SELECTED_KEY_SUFFIX,
        value: _ouuid,
      );
      return OperationSelected(data);
    }
    return null;
  }

  Future<OperationState> _unselect(OperationCommand command) async {
    final unselected = await _unset(
      clear: true,
    );
    if (unselected != null) {
      return toOK(
        command,
        unselected,
        result: unselected.data,
      );
    }
    return toError(
      command,
      OperationBlocError('No operation was selected'),
    );
  }

  Future<OperationState> _unset({
    @required bool clear,
    Operation selected,
  }) async {
    final operation = _ouuid == null ? null : repo[_ouuid] ?? selected;
    _ouuid = null;

    if (clear) {
      await Storage.secure.delete(
        key: SELECTED_KEY_SUFFIX,
      );
    }

    return operation != null ? OperationUnselected(operation) : null;
  }

  @override
  Future<void> close() async {
    await repo.dispose();
    await incidents.dispose();
    return super.close();
  }

  @override
  OperationBlocError createError(Object error, {StackTrace stackTrace}) => OperationBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}

/// ---------------------
/// Commands
/// ---------------------
abstract class OperationCommand<S, T> extends BlocCommand<S, T> {
  OperationCommand(
    S data, {
    props = const [],
  }) : super(data, props);
}

class LoadOperations extends OperationCommand<void, List<Operation>> {
  LoadOperations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class CreateOperation extends OperationCommand<Operation, Operation> {
  final bool selected;
  final List<String> units;
  final Incident incident;
  CreateOperation(
    Operation operation, {
    this.selected = true,
    this.units,
    this.incident,
  }) : super(operation, props: [selected, incident, units]);

  @override
  String toString() => '$runtimeType {data: $data, selected: $selected, incident: $incident, units: $units}';
}

class UpdateOperation extends OperationCommand<Operation, Operation> {
  final bool selected;
  final Incident incident;
  UpdateOperation(
    Operation operation, {
    this.selected = true,
    this.incident,
  }) : super(operation, props: [selected, incident]);

  @override
  String toString() => '$runtimeType {data: $data, selected: $selected, incident: $incident}';
}

class SelectOperation extends OperationCommand<String, Operation> {
  SelectOperation(String uuid) : super(uuid);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class UnselectOperation extends OperationCommand<void, Operation> {
  UnselectOperation() : super(null);

  @override
  String toString() => '$runtimeType';
}

class DeleteOperation extends OperationCommand<String, Operation> {
  DeleteOperation(String uuid) : super(uuid);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class UnloadOperations extends OperationCommand<void, List<Operation>> {
  UnloadOperations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class _StateChange extends OperationCommand<OperationState, Operation> {
  _StateChange(
    OperationState state,
  ) : super(state);

  @override
  String toString() => '$runtimeType {state: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class OperationState<T> extends BlocEvent<T> {
  OperationState(
    T data, {
    props = const [],
    StackTrace stackTrace,
    this.isRemote = false,
  }) : super(data, props: [...props, isRemote], stackTrace: stackTrace);

  final bool isRemote;
  bool get isLocal => !isRemote;

  bool isEmpty() => this is OperationsEmpty;
  bool isLoaded() => this is OperationsLoaded;
  bool isCreated() => this is OperationCreated;
  bool isUpdated() => this is OperationUpdated;
  bool isDeleted() => this is OperationDeleted;
  bool isError() => this is OperationBlocError;
  bool isUnselected() => this is OperationUnselected;
  bool isSelected() =>
//      this is OperationCreated && (this as OperationCreated).selected ||
//      this is OperationUpdated && (this as OperationUpdated).selected ||
      this is OperationSelected;

  /// Check if data referencing [Operation.uuid] should be loaded
  /// This method will return true if
  /// 1. Operation was selected
  /// 2. Operation was a status that should load data
  /// 3. [Operation.uuid] in [OperationState.data] is equal to [ouuid] given
  bool shouldLoad(String ouuid,
          {List<OperationStatus> include: const [
            OperationStatus.completed,
          ]}) =>
      (isSelected() && (data as Operation).uuid != ouuid) &&
      !include.contains(
        (data as Operation).status,
      );

  /// Check if data referencing [Operation.uuid] should be unloaded
  /// This method will return true if
  /// 1. Operation was unselected
  /// 2. Operation was changed to a status that should unload data
  /// 3. [Operation.uuid] in [OperationState.data] is equal to [ouuid] given
  bool shouldUnload(String ouuid,
          {List<OperationStatus> include: const [
            OperationStatus.completed,
          ]}) =>
      isEmpty() ||
      isUnselected() ||
      (isUpdated() && (data as Operation).uuid == ouuid) &&
          include.contains(
            (data as Operation).status,
          );
}

class OperationsEmpty extends OperationState<void> {
  OperationsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class OperationUnselected extends OperationState<Operation> {
  OperationUnselected([Operation operation]) : super(operation);

  @override
  String toString() => '$runtimeType {operation: $data}';
}

class OperationsLoaded extends OperationState<Iterable<String>> {
  OperationsLoaded(
    Iterable<String> data, {
    this.incidents,
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [incidents]);

  final List<String> incidents;

  @override
  String toString() => '$runtimeType {'
      'operations: $data, '
      'isRemote: $isRemote, '
      'incidents: $incidents, '
      '}';
}

class OperationCreated extends OperationState<Operation> {
  final bool selected;
  final Incident incident;
  final List<String> units;
  OperationCreated(
    Operation data, {
    this.units,
    this.incident,
    this.selected = true,
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [selected, incident, units]);

  @override
  String toString() => '$runtimeType '
      '{operation: $data, '
      'selected: $selected, '
      'units: $units, '
      'isRemote: $isRemote'
      '}';
}

class OperationUpdated extends OperationState<Operation> {
  final bool selected;
  final Incident incident;
  OperationUpdated(
    Operation data, {
    this.incident,
    this.selected = true,
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [incident, selected]);

  @override
  String toString() => '$runtimeType {'
      'operation: $data, '
      'selected: $selected, '
      'incident: $incident, '
      'isRemote: $isRemote'
      '}';
}

class OperationSelected extends OperationState<Operation> {
  OperationSelected(Operation data) : super(data);

  @override
  String toString() => '$runtimeType {operation: $data}';
}

class OperationDeleted extends OperationState<Operation> {
  OperationDeleted(
    Operation data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {operation: $data, isRemote: $isRemote}';
}

class OperationsUnloaded extends OperationState<Iterable<Operation>> {
  OperationsUnloaded(Iterable<Operation> operations) : super(operations);

  @override
  String toString() => '$runtimeType {operations: $data}';
}

/// ---------------------
/// Error States
/// ---------------------
class OperationBlocError extends OperationState<Object> {
  OperationBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------
class OperationBlocException implements Exception {
  OperationBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final OperationState state;
  final StackTrace stackTrace;
  final OperationCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}

class OperationNotFoundBlocException extends OperationBlocException {
  OperationNotFoundBlocException(
    String ouuid,
    OperationState state, {
    OperationCommand command,
    StackTrace stackTrace,
  }) : super('Operation $ouuid not found locally', state, command: command, stackTrace: stackTrace);
}
