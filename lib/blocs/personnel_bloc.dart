import 'dart:async';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/personnel_repository.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'core.dart';
import 'mixins.dart';
import 'incident_bloc.dart';

typedef void PersonnelCallback(VoidCallback fn);

class PersonnelBloc extends BaseBloc<PersonnelCommand, PersonnelState, PersonnelBlocError>
    with
        LoadableBloc<List<Personnel>>,
        CreatableBloc<Personnel>,
        UpdatableBloc<Personnel>,
        DeletableBloc<Personnel>,
        UnloadableBloc<List<Personnel>> {
  PersonnelBloc(this.repo, this.incidentBloc) {
    assert(repo != null, "repo can not be null");
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    _subscriptions
      ..add(incidentBloc.listen(
        _processIncidentEvent,
      ))
      // Process tracking messages
      ..add(service.messages.listen(
        _processPersonnelMessage,
      ));
  }

  void _processIncidentEvent(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty) {
        if (state.shouldUnload(iuuid) && repo.isReady) {
          add(UnloadPersonnels(repo.iuuid));
        } else if (state.isSelected()) {
          add(LoadPersonnels(state.data.uuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  void _processPersonnelMessage(event) {
    try {
      add(_InternalMessage(event));
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

  /// Get [PersonnelRepository]
  final PersonnelRepository repo;

  /// Get [Personnel] from [uuid]
  Personnel operator [](String uuid) => repo[uuid];

  /// Get [PersonnelService]
  PersonnelService get service => repo.service;

  /// [Incident] that manages given [devices]
  String get iuuid => repo.iuuid;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.iuuid == null;

  @override
  PersonnelState get initialState => PersonnelsEmpty();

  /// Get personnel
  Map<String, Personnel> get personnels => repo.map;

  /// Find [Personnel] from [user]
  Iterable<Personnel> find(
    User user, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      repo.find(user, exclude: exclude);

  /// Stream of changes on given [personnel]
  Stream<Personnel> onChanged(Personnel personnel) => where(
        (state) =>
            (state is PersonnelUpdated && state.data.uuid == personnel.uuid) ||
            (state is PersonnelsLoaded && state.data.contains(personnel.uuid)),
      ).map((state) => state is PersonnelsLoaded ? repo[personnel.uuid] : state.data);

  /// Get count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      repo.count(exclude: exclude);

  void _assertState() {
    if (incidentBloc.isUnset) {
      throw PersonnelBlocException(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'PersonnelBloc.load()'",
        state,
      );
    }
  }

  void _assertData(Personnel data) {
    if (data?.uuid == null) {
      throw ArgumentError(
        "Personnel have no uuid",
      );
    }
    TrackingUtils.assertRef(data);
  }

  /// Fetch personnel from [service]
  Future<List<Personnel>> load() async {
    _assertState();
    return dispatch<List<Personnel>>(
      LoadPersonnels(iuuid ?? incidentBloc.selected.uuid),
    );
  }

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) {
    _assertState();
    return dispatch<Personnel>(
      CreatePersonnel(
        iuuid ?? incidentBloc.selected.uuid,
        personnel.cloneWith(
          // Personnels should contain a tracking reference when
          // they are created. [TrackingBloc] will use this
          // reference to create a [Tracking] instance which the
          // backend will create apriori using the same uuid.
          // This allows for offline creation of tracking objects
          // in apps resulting in a better user experience
          tracking: TrackingUtils.ensureRef(personnel),
        ),
      ),
    );
  }

  /// Update given personnel
  Future<Personnel> update(Personnel personnel) {
    _assertState();
    return dispatch<Personnel>(
      UpdatePersonnel(personnel),
    );
  }

  /// Delete given personnel
  Future<Personnel> delete(String uuid) {
    _assertState();
    return dispatch<Personnel>(
      DeletePersonnel(repo[uuid]),
    );
  }

  /// Unload [personnels] from local storage
  Future<List<Personnel>> unload() {
    _assertState();
    return dispatch<List<Personnel>>(
      UnloadPersonnels(iuuid),
    );
  }

  @override
  Stream<PersonnelState> execute(PersonnelCommand command) async* {
    if (command is LoadPersonnels) {
      yield await _load(command);
    } else if (command is CreatePersonnel) {
      yield await _create(command);
    } else if (command is UpdatePersonnel) {
      yield await _update(command);
    } else if (command is DeletePersonnel) {
      yield await _delete(command);
    } else if (command is UnloadPersonnels) {
      yield await _unload(command);
    } else if (command is _InternalMessage) {
      yield await _process(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Future<PersonnelState> _load(LoadPersonnels command) async {
    var personnels = await repo.load(command.data);
    return toOK(
      command,
      PersonnelsLoaded(repo.keys),
      result: personnels,
    );
  }

  Future<PersonnelState> _create(CreatePersonnel command) async {
    _assertData(command.data);
    var personnel = await repo.create(command.iuuid, command.data);
    return toOK(
      command,
      PersonnelCreated(personnel),
      result: personnel,
    );
  }

  Future<PersonnelState> _update(UpdatePersonnel command) async {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final personnel = await repo.update(command.data);
    return toOK(
      command,
      PersonnelUpdated(personnel, previous),
      result: personnel,
    );
  }

  Future<PersonnelState> _delete(DeletePersonnel command) async {
    _assertData(command.data);
    final personnel = await repo.delete(command.data.uuid);
    return toOK(
      command,
      PersonnelDeleted(personnel),
      result: personnel,
    );
  }

  Future<PersonnelState> _unload(UnloadPersonnels command) async {
    final personnels = await repo.unload();
    return toOK(
      command,
      PersonnelsUnloaded(personnels),
      result: personnels,
    );
  }

  Future<PersonnelState> _process(_InternalMessage event) async {
    switch (event.data.type) {
      case PersonnelMessageType.PersonnelChanged:
        if (repo.containsKey(event.data.uuid)) {
          final current = repo[event.data.uuid];
          final next = current.withJson(event.data.json);
          await repo.replace(
            event.data.uuid,
            next,
          );
          return PersonnelUpdated(next, current);
        }
        break;
    }
    return PersonnelBlocError("Personnel message not recognized: $event");
  }

  @override
  PersonnelBlocError createError(Object error, {StackTrace stackTrace}) => PersonnelBlocError(
        error,
        stackTrace: StackTrace.current,
      );

  @override
  Future<void> close() async {
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
    await repo.dispose();
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class PersonnelCommand<S, T> extends BlocCommand<S, T> {
  PersonnelCommand(S data, [props = const []]) : super(data, props);
}

class LoadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  LoadPersonnels(String iuuid) : super(iuuid);

  @override
  String toString() => 'LoadPersonnels {iuuid: $data}';
}

class CreatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  final String iuuid;
  CreatePersonnel(this.iuuid, Personnel data) : super(data);

  @override
  String toString() => 'CreatePersonnel {iuuid: $iuuid, personnel: $data}';
}

class UpdatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  UpdatePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'UpdatePersonnel {personnel: $data}';
}

class DeletePersonnel extends PersonnelCommand<Personnel, Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'DeletePersonnel {personnel: $data}';
}

class _InternalMessage extends PersonnelCommand<PersonnelMessage, PersonnelMessage> {
  _InternalMessage(PersonnelMessage data) : super(data);

  @override
  String toString() => '_InternalMessage {message: $data}';
}

class UnloadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  UnloadPersonnels(String iuuid) : super(iuuid);

  @override
  String toString() => 'UnloadPersonnels {iuuid: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class PersonnelState<T> extends BlocEvent<T> {
  PersonnelState(
    T data, {
    StackTrace stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isError() => this is PersonnelBlocError;
  bool isEmpty() => this is PersonnelsEmpty;
  bool isLoaded() => this is PersonnelsLoaded;
  bool isCreated() => this is PersonnelCreated;
  bool isUpdated() => this is PersonnelUpdated;
  bool isDeleted() => this is PersonnelDeleted;
  bool isUnloaded() => this is PersonnelsUnloaded;

  bool isStatusChanged() => false;
  bool isTracked() => (data is Personnel) ? (data as Personnel).tracking?.uuid != null : false;
  bool isRetired() => (data is Personnel) ? (data as Personnel).status == PersonnelStatus.Retired : false;
}

class PersonnelsEmpty extends PersonnelState<Null> {
  PersonnelsEmpty() : super(null);

  @override
  String toString() => 'PersonnelsEmpty';
}

class PersonnelsLoaded extends PersonnelState<List<String>> {
  PersonnelsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'PersonnelsLoaded {data: $data}';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(Personnel data) : super(data);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => 'PersonnelCreated {data: $data}';
}

class PersonnelUpdated extends PersonnelState<Personnel> {
  final Personnel previous;
  PersonnelUpdated(Personnel data, this.previous) : super(data);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  bool isStatusChanged() => data.status != previous.status;

  @override
  String toString() => 'PersonnelUpdated {data: $data, previous: $previous}';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelDeleted {data: $data}';
}

class PersonnelsUnloaded extends PersonnelState<List<Personnel>> {
  PersonnelsUnloaded(List<Personnel> personnel) : super(personnel);

  @override
  String toString() => 'PersonnelsUnloaded {data: $data}';
}

/// ---------------------
/// Error States
/// ---------------------

class PersonnelBlocError extends PersonnelState<Object> {
  PersonnelBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {data: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class PersonnelBlocException implements Exception {
  PersonnelBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final PersonnelState state;
  final StackTrace stackTrace;
  final Object command;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
