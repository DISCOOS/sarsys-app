import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import 'operation_commands.dart';
import 'operation_states.dart';

export 'operation_commands.dart';
export 'operation_states.dart';

class OperationBloc
    extends StatefulBloc<OperationCommand, OperationState, OperationBlocError, String, Operation, OperationService>
    with
        LoadableBloc<List<Operation>>,
        CreatableBloc<Operation>,
        UpdatableBloc<Operation>,
        DeletableBloc<Operation>,
        UnloadableBloc<List<Operation>> {
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

    // Notify when Incident state has changed
    forward<Incident>(
      (t) => _NotifyRepositoryStateChanged<Incident>(t),
    );

    // Notify when Operation state has changed
    forward<Operation>(
      (t) => _NotifyRepositoryStateChanged<Operation>(t),
    );
  }

  /// Key suffix for storing
  /// selected [Operation.uuid]
  /// in [Storage.secure] for
  /// each user
  ///
  static const SELECTED_KEY_SUFFIX = 'selected_ouuid';

  /// Get [UserBloc]
  final UserBloc userBloc;

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

  /// Get [IncidentRepository]
  IncidentRepository get incidents => repo.incidents;

  /// Get [OperationRepository]
  final OperationRepository repo;

  /// Get all [Operation]s
  Iterable<Operation> get values => repo.values;

  /// Get [Operation] from [uuid]
  Operation operator [](String uuid) => repo[uuid];

  /// All repositories
  Iterable<StatefulRepository> get repos => [incidents, repo];

  /// Get [OperationService]
  OperationService get service => repo.service;

  String _ouuid;

  void _processUserState(UserState state) {
    try {
      if (isOpen) {
        if (state.shouldLoad() && !repo.isReady) {
          dispatch(LoadOperations());
        } else if (state.shouldUnload(isOnline: isOnline) && repo.isReady) {
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

  /// Check if current [user] is authorized access to [operation] with given [role].
  ///
  /// If [operation] is not given, [selected] is used instead.
  ///
  bool isAuthorizedAs(UserRole role, {Operation operation}) => userBloc.isAuthorizedAs(
        operation ?? selected,
        role,
      );

  /// Stream of switched between given operations
  Stream<Operation> get onSwitched => where(
        (state) => state is OperationSelected && state.data.uuid != _ouuid,
      ).map((state) => state.data);

  /// Stream of operation changes
  Stream<Operation> onChanged([Operation operation]) => where(
        (state) => _isOn(operation, state) && state.isCreated() || state.isUpdated() || state.isSelected(),
      ).map((state) => state.data);

  bool _isOn(Operation operation, OperationState state) => (operation == null || state.data.uuid == operation.uuid);

  String _assertUuid(Operation data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Operation have no uuid",
      );
    }
    return data?.uuid;
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
    final operation = command.data;
    if (operation?.uuid == null) {
      throw ArgumentError(
        "Operation have no uuid",
      );
    }
    if (operation?.incident?.uuid == null) {
      throw ArgumentError(
        "Operation ${operation.uuid} have no incident uuid",
      );
    }
    if (operation?.incident?.uuid != command.incident.uuid) {
      throw ArgumentError(
        "Operation ${operation.uuid} does not reference "
        "incident ${command.incident.uuid}",
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
    } else if (command is _NotifyRepositoryStateChanged) {
      yield _notify(command);
    } else if (command is _NotifyBlocStateChanged) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<OperationState> _load(LoadOperations command) async* {
    // Get currently selected uuid
    String ouuid = await _readSelected();

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
    final operation = operations.firstWhere(
      (operation) => ouuid == operation.uuid,
      orElse: () => null,
    );
    final unselected = await _unset(selected: operation);
    final selected = await _set(operation);

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
    if (selected != null) {
      yield selected;
    }
    yield loaded;

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
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<String> _readSelected() async {
    _ouuid = _ouuid ??
        await Storage.readUserValue(
          userBloc.user,
          suffix: SELECTED_KEY_SUFFIX,
        );
    return _ouuid;
  }

  Stream<OperationState> _create(CreateOperation command) async* {
    _assertData(command);
    // Execute commands
    incidents.apply(command.incident);
    final operation = repo.apply(command.data);
    final unselected = command.selected ? await _unset() : null;
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
      [
        repo.onRemote(operation.uuid),
        incidents.onRemote(operation.incident.uuid),
      ],
      toState: (_) => OperationCreated(
        operation,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _update(UpdateOperation command) async* {
    final uuid = _assertUuid(command.data);
    // Execute command
    final previous = repo.get(uuid);
    final operation = repo.apply(command.data);
    if (command.incident != null) {
      incidents.apply(command.incident);
    }
    final select = command.selected && command.data.uuid != _ouuid;
    final unselected = select ? await _unset() : null;
    final selected = select ? await _set(operation) : null;
    final selectionChanged = unselected != selected;
    // Complete request
    final updated = toOK(
      command,
      OperationUpdated(
        operation,
        previous,
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
        previous,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _delete(DeleteOperation command) async* {
    final onRemote = Completer<Operation>();
    // Unselect if was selected
    final unselected = command.data == _ouuid ? await _unset() : null;
    // Execute command
    var operation = repo.delete(
      command.data,
      onResult: onRemote,
    );
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
      [onRemote.future],
      toState: (_) => OperationDeleted(
        operation,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<OperationState> _unload(UnloadOperations command) async* {
    // Unselect if selected
    final unselected = await _unset();

    // Execute commands
    await incidents.close();
    List<Operation> operations = await repo.close();

    // Complete request
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
      final unselected = await _unset(selected: operation);
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

  Future<OperationSelected> _set(Operation operation) async {
    OperationSelected selected;
    if (_ouuid != operation?.uuid) {
      _ouuid = operation?.uuid;
      await Storage.writeUserValue(
        userBloc.user,
        suffix: SELECTED_KEY_SUFFIX,
        value: _ouuid,
      );
      selected = OperationSelected(operation);
    }
    return selected;
  }

  Future<OperationState> _unselect(OperationCommand command) async {
    final unselected = await _unset();
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
    Operation selected,
  }) async {
    OperationUnselected unselected;
    if (selected?.uuid != _ouuid) {
      final operation = repo[_ouuid];
      if (operation != null) {
        unselected = OperationUnselected(operation);
      }
      await Storage.deleteUserValue(
        userBloc.user,
        suffix: SELECTED_KEY_SUFFIX,
      );
    }
    _ouuid = null;
    return unselected;
  }

  OperationState _notify(_NotifyRepositoryStateChanged command) {
    final state = command.state;

    switch (command.type) {
      case Operation:
        return _notifyOperationChanged(command, state);
    }

    return toOK(
      command,
      OperationIncidentUpdated(
        command.state as Incident,
        command.previous as Incident,
        selected,
        isRemote: command.isRemote,
      ),
      result: state,
    );
  }

  OperationState _notifyOperationChanged(_NotifyRepositoryStateChanged command, state) {
    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          OperationCreated(
            state,
            selected: selected != null,
            isRemote: command.isRemote,
            incident: selected != null ? incidents[selected.incident?.uuid] : null,
          ),
          result: state,
        );
      case StorageStatus.updated:
        return toOK(
          command,
          OperationUpdated(
            state,
            command.previous,
            selected: selected != null,
            isRemote: command.isRemote,
            incident: selected != null ? incidents[selected.incident?.uuid] : null,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          OperationDeleted(
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
  OperationBlocError createError(Object error, {StackTrace stackTrace}) => OperationBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}

/// ---------------------
/// Internal commands
/// ---------------------

class _NotifyRepositoryStateChanged<T> extends OperationCommand<StorageTransition<T>, T>
    with NotifyRepositoryStateChangedMixin {
  _NotifyRepositoryStateChanged(StorageTransition<T> transition) : super(transition);
}

class _NotifyBlocStateChanged<T> extends OperationCommand<OperationState<T>, T>
    with NotifyBlocStateChangedMixin<OperationState<T>, T> {
  _NotifyBlocStateChanged(OperationState state) : super(state);
}
