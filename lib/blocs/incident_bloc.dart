import 'dart:async';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/repositories/incident_repository.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';

import 'core.dart';
import 'mixins.dart';
import 'user_bloc.dart';

class IncidentBloc extends BaseBloc<IncidentCommand, IncidentState, IncidentBlocError>
    with
        LoadableBloc<List<Incident>>,
        CreatableBloc<Incident>,
        UpdatableBloc<Incident>,
        DeletableBloc<Incident>,
        UnloadableBloc<List<Incident>> {
  IncidentBloc(this.repo, BlocEventBus bus, this.userBloc) : super(bus: bus) {
    assert(this.repo != null, "repository can not be null");
    assert(this.repo.service != null, "service can not be null");
    assert(this.userBloc != null, "userBloc can not be null");
    _subscription = userBloc.listen(
      _processUserEvent,
    );
  }

  /// Key suffix for storing
  /// selected [Incident.uuid]
  /// in [Storage.secure] for
  /// each user
  ///
  static const SELECTED_IUUID_KEY_SUFFIX = 'selected_iuuid';

  /// Get [UserBloc]
  final UserBloc userBloc;

  /// Get [IncidentRepository]
  final IncidentRepository repo;

  /// Get [IncidentService]
  IncidentService get service => repo.service;

  String _iuuid;
  StreamSubscription _subscription;

  void _processUserEvent(UserState state) {
    if (_subscription != null) {
      if (!isUnset && state.isUnset()) {
        if (!isUnset) {
          add(UnselectIncident());
        }
      } else if (state.isAuthenticated()) {
        add(LoadIncidents());
      }
    }
  }

  @override
  IncidentUnset get initialState => IncidentUnset();

  /// Check if no incident selected
  bool get isUnset => _iuuid == null;

  /// Get selected incident
  Incident get selected => repo[_iuuid];

  /// Get incident from uuid
  Incident get(String uuid) => repo[uuid];

  /// Get incidents
  List<Incident> get incidents => repo.values;

  /// Get incident uuids
  List<String> get iuuids => repo.keys;

  /// Stream of switched between given incidents
  Stream<Incident> get onSwitched => where(
        (state) => state is IncidentSelected && state.data.uuid != _iuuid,
      ).map((state) => state.data);

  /// Stream of incident changes
  Stream<Incident> onChanged([Incident incident]) => where(
        (state) => _isOn(incident, state) && state.isCreated() || state.isUpdated() || state.isSelected(),
      ).map((state) => state.data);

  bool _isOn(Incident incident, IncidentState state) => (incident == null || state.data.uuid == incident.uuid);

  void _assertData(Incident data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Incident have no uuid",
      );
    }
  }

  /// Fetch incidents from [repo]
  Future<List<Incident>> load() async {
    return dispatch(
      LoadIncidents(),
    );
  }

  /// Select [Incident] with given [Incident.uuid]
  Future<Incident> select(String uuid) {
    if (emptyAsNull(uuid) == null) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    return dispatch(SelectIncident(uuid));
  }

  /// Unselect [selected]
  Future<Incident> unselect() {
    return dispatch(UnselectIncident());
  }

  /// Create given incident
  Future<Incident> create(
    Incident incident, {
    bool selected = true,
    List<String> units = const [],
  }) {
    return dispatch<Incident>(CreateIncident(
      incident,
      selected: selected,
      units: units,
    ));
  }

  /// Update given incident
  Future<Incident> update(Incident incident, {bool selected = true}) {
    return dispatch(UpdateIncident(incident, selected: selected));
  }

  /// Delete given incident
  Future<Incident> delete(String uuid) {
    if (isEmptyOrNull(uuid)) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    return dispatch(DeleteIncident(uuid));
  }

  /// Clear all incidents
  Future<List<Incident>> unload() {
    return dispatch(UnloadIncidents());
  }

  @override
  Stream<IncidentState> execute(IncidentCommand command) async* {
    if (command is LoadIncidents) {
      yield* _load(command);
    } else if (command is CreateIncident) {
      yield* _create(command);
    } else if (command is UpdateIncident) {
      yield* _update(command);
    } else if (command is SelectIncident) {
      yield* _select(command);
    } else if (command is DeleteIncident) {
      yield* _delete(command);
    } else if (command is UnloadIncidents) {
      yield* _unload(command);
    } else if (command is UnselectIncident) {
      yield await _unselect(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<IncidentState> _load(LoadIncidents command) async* {
    // Get currently selected uuid
    final iuuid = _iuuid;

    // Execute command
    final incidents = await repo.load();

    // Unselect and reselect
    final unselected = await _unset(clear: true);
    final selected = await _set(
      incidents.firstWhere(
        (incident) => iuuid == incident.uuid,
        orElse: () => null,
      ),
    );

    // Complete request
    final loaded = toOK(
      command,
      IncidentsLoaded(incidents),
      result: repo.values.toList(),
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield loaded;
    if (selected != null) {
      yield selected;
    }
  }

  Stream<IncidentState> _create(CreateIncident command) async* {
    _assertData(command.data);
    // Execute command
    final incident = await repo.create(command.data);
    final unselected = command.selected ? await _unset(clear: true) : null;
    final selected = command.selected ? await _set(incident) : null;
    // Complete request
    final created = toOK(
      command,
      IncidentCreated(incident, units: command.units),
      result: incident,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield created;
    if (selected != null) {
      yield selected;
    }
  }

  Stream<IncidentState> _update(UpdateIncident command) async* {
    _assertData(command.data);
    // Execute command
    var incident = await repo.update(command.data);
    var select = command.selected && command.data.uuid != _iuuid;
    final unselected = select ? await _unset(clear: true) : null;
    final selected = select ? await _set(incident) : null;
    final selectionChanged = unselected != selected;
    // Complete request
    final updated = toOK(
      command,
      IncidentUpdated(incident),
      result: incident,
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
  }

  Stream<IncidentState> _delete(DeleteIncident command) async* {
    final selected = this.selected;
    // Execute command
    var incident = await repo.delete(command.data);
    // Unselect if was selected
    final unselected = command.data == _iuuid
        ? await _unset(
            selected: selected,
            clear: true,
          )
        : null;
    // Complete request
    final deleted = toOK(
      command,
      IncidentDeleted(incident),
      result: incident,
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield deleted;
  }

  Stream<IncidentState> _unload(UnloadIncidents command) async* {
    final selected = this.selected;
    // Execute command
    List<Incident> incidents = await repo.clear();
    // Complete request
    final unselected = await _unset(
      selected: selected,
      clear: false,
    );
    final unloaded = toOK(
      command,
      IncidentsUnloaded(incidents),
    );
    // Notify listeners
    if (unselected != null) {
      yield unselected;
    }
    yield unloaded;
  }

  Stream<IncidentState> _select(SelectIncident command) async* {
    if (repo.containsKey(command.data)) {
      final incident = repo[command.data];
      final unselected = command.data != _iuuid ? await _unset(clear: true) : null;
      final selected = toOK(
        command,
        await _set(repo[command.data]),
        result: incident,
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
        IncidentBlocError(
          'Incident ${command.data} not found locally',
          stackTrace: command.stackTrace,
        ),
      );
    }
  }

  Future<IncidentSelected> _set(Incident data) async {
    _iuuid = data?.uuid;
    if (_iuuid != null) {
      await Storage.writeUserValue(
        userBloc.user,
        key: SELECTED_IUUID_KEY_SUFFIX,
        value: _iuuid,
      );
      return IncidentSelected(data);
    }
    return null;
  }

  Future<IncidentState> _unselect(IncidentCommand command) async {
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
      IncidentBlocError('No incident was selected'),
    );
  }

  Future<IncidentState> _unset({
    @required bool clear,
    Incident selected,
  }) async {
    final incident = _iuuid == null ? null : repo[_iuuid] ?? selected;
    _iuuid = null;

    if (clear) {
      await Storage.secure.delete(
        key: SELECTED_IUUID_KEY_SUFFIX,
      );
    }

    return incident != null ? IncidentUnset(incident) : null;
  }

  @override
  Future<void> close() async {
    _subscription?.cancel();
    _subscription = null;
    await repo.dispose();
    return super.close();
  }

  @override
  IncidentBlocError createError(Object error, {StackTrace stackTrace}) => IncidentBlocError(
        error,
        stackTrace: StackTrace.current,
      );
}

/// ---------------------
/// Commands
/// ---------------------
abstract class IncidentCommand<S, T> extends BlocCommand<S, T> {
  IncidentCommand(
    S data, {
    props = const [],
  }) : super(data, props);
}

class LoadIncidents extends IncidentCommand<void, List<Incident>> {
  LoadIncidents() : super(null);

  @override
  String toString() => 'LoadIncidents {}';
}

class CreateIncident extends IncidentCommand<Incident, Incident> {
  final bool selected;
  final List<String> units;
  CreateIncident(
    Incident data, {
    this.selected = true,
    this.units,
  }) : super(data, props: [selected, units]);

  @override
  String toString() => 'CreateIncident {data: $data, selected: $selected, units: $units}';
}

class UpdateIncident extends IncidentCommand<Incident, Incident> {
  final bool selected;
  UpdateIncident(Incident data, {this.selected = true}) : super(data, props: [selected]);

  @override
  String toString() => 'UpdateIncident {data: $data, selected: $selected}';
}

class SelectIncident extends IncidentCommand<String, Incident> {
  SelectIncident(String uuid) : super(uuid);

  @override
  String toString() => 'SelectIncident {data: $data}';
}

class UnselectIncident extends IncidentCommand<void, Incident> {
  UnselectIncident() : super(null);

  @override
  String toString() => 'UnselectIncident';
}

class DeleteIncident extends IncidentCommand<String, Incident> {
  DeleteIncident(String uuid) : super(uuid);

  @override
  String toString() => 'DeleteIncident {data: $data}';
}

class UnloadIncidents extends IncidentCommand<void, List<Incident>> {
  UnloadIncidents() : super(null);

  @override
  String toString() => 'UnloadIncidents {}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class IncidentState<T> extends BlocEvent<T> {
  IncidentState(
    T data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isUnset() => this is IncidentUnset;
  bool isLoaded() => this is IncidentsLoaded;
  bool isCreated() => this is IncidentCreated;
  bool isUpdated() => this is IncidentUpdated;
  bool isSelected() => this is IncidentSelected;
  bool isDeleted() => this is IncidentDeleted;
  bool isError() => this is IncidentBlocError;

  /// Check if data referencing [Incident.uuid] should be unloaded
  /// This method will return true if
  /// 1. IncidentBloc was unset
  /// 2. Given Incident was changed to a status that should unload data
  bool shouldUnload(String uuid,
          {List<IncidentStatus> include: const [
            IncidentStatus.Resolved,
            IncidentStatus.Cancelled,
          ]}) =>
      isUnset() ||
      (isUpdated() && (this as IncidentUpdated).data.uuid == uuid) &&
          include.contains(
            (this as IncidentUpdated).data.status,
          );
}

class IncidentUnset extends IncidentState<Incident> {
  IncidentUnset([Incident incident]) : super(incident);

  @override
  String toString() => 'IncidentUnset {incident: $data}';
}

class IncidentsLoaded extends IncidentState<Iterable<Incident>> {
  IncidentsLoaded(Iterable<Incident> data) : super(data);

  @override
  String toString() => 'IncidentsLoaded {incidents: $data}';
}

class IncidentCreated extends IncidentState<Incident> {
  final bool selected;
  final List<String> units;
  IncidentCreated(
    Incident data, {
    this.selected = true,
    this.units,
  }) : super(data, props: [selected, units]);

  @override
  String toString() => 'IncidentCreated {incident: $data, selected: $selected, units: $units}';
}

class IncidentUpdated extends IncidentState<Incident> {
  final bool selected;
  IncidentUpdated(Incident data, {this.selected = true}) : super(data, props: [selected]);

  @override
  String toString() => 'IncidentUpdated {incident: $data, selected: $selected}';
}

class IncidentSelected extends IncidentState<Incident> {
  IncidentSelected(Incident data) : super(data);

  @override
  String toString() => 'IncidentSelected {incident: $data,}';
}

class IncidentDeleted extends IncidentState<Incident> {
  IncidentDeleted(Incident data) : super(data);

  @override
  String toString() => 'IncidentDeleted {incident: $data}';
}

class IncidentsUnloaded extends IncidentState<Iterable<Incident>> {
  IncidentsUnloaded(Iterable<Incident> incidents) : super(incidents);

  @override
  String toString() => 'IncidentsUnloaded {incidents: $data}';
}

/// ---------------------
/// Error States
/// ---------------------
class IncidentBlocError extends IncidentState<Object> {
  IncidentBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class IncidentBlocException implements Exception {
  IncidentBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final IncidentState state;
  final StackTrace stackTrace;
  final IncidentCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
