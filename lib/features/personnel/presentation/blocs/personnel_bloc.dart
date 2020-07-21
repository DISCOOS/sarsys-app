import 'dart:async';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:uuid/uuid.dart';

typedef void PersonnelCallback(VoidCallback fn);

class PersonnelBloc extends BaseBloc<PersonnelCommand, PersonnelState, PersonnelBlocError>
    with
        LoadableBloc<List<Personnel>>,
        CreatableBloc<Personnel>,
        UpdatableBloc<Personnel>,
        DeletableBloc<Personnel>,
        UnloadableBloc<List<Personnel>>,
        ConnectionAwareBloc {
  ///
  /// Default constructor
  ///
  PersonnelBloc(this.repo, BlocEventBus bus, this.affiliationBloc, this.operationBloc) : super(bus: bus) {
    assert(repo != null, "repo can not be null");
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(affiliationBloc != null, "affiliationBloc can not be null");

    registerStreamSubscription(operationBloc.listen(
      // Load and unload personnels as needed
      _processOperationState,
    ));

    registerStreamSubscription(service.messages.listen(
      // Update from messages pushed from backend
      _processPersonnelMessage,
    ));

    registerStreamSubscription(affiliationBloc.persons.onChanged.listen(
      // Handle person conflicts
      _processPersonConflicts,
    ));
  }

  void _processOperationState(OperationState state) async {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad(ouuid)) {
          await dispatch(LoadPersonnels(state.data.uuid));
          if (state.isSelected()) {
            await mobilizeUser();
          }
        } else if (state.shouldUnload(ouuid) && repo.isReady) {
          dispatch(UnloadPersonnels(repo.ouuid));
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

  void _processPersonnelMessage(PersonnelMessage event) {
    try {
      add(_InternalMessage(event));
    } catch (error, stackTrace) {
      BlocSupervisor.delegate.onError(
        this,
        error,
        stackTrace,
      );
      onError(error, stackTrace);
    }
  }

  void _processPersonConflicts(StorageTransition<Person> state) {
    try {
      if (PersonRepository.isDuplicateUser(state)) {
        // Find current person usages and replace with existing user
        final duplicate = state.from.value.uuid;
        final existing = state.conflict.base;
        findUser(
          duplicate,
          exclude: [],
        ).map((personnel) => personnel.mergeWith({"person": existing})).forEach(update);
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

  /// Get [AffiliationBloc]
  final AffiliationBloc affiliationBloc;

  /// Get [OperationBloc]
  final OperationBloc operationBloc;

  /// Get [PersonnelRepository]
  final PersonnelRepository repo;

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [repo];

  /// Get [Personnel] from [uuid]
  Personnel operator [](String uuid) => repo[uuid];

  /// Get [PersonnelService]
  PersonnelService get service => repo.service;

  /// [Incident] that manages given [devices]
  String get ouuid => repo.ouuid;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.ouuid == null;

  /// Check if bloc is ready
  bool get isReady => repo.isReady;

  @override
  PersonnelState get initialState => PersonnelsEmpty();

  /// Get [Personnel] from [puuids]
  Iterable<Aggregate> from(List<String> puuids) =>
      puuids.where((puuid) => repo.containsKey(puuid)).map((puuid) => repo[puuid]).toList();

  /// Find [Personnel] from [user]
  Iterable<Personnel> findUser(
    String userId, {
    bool Function(Personnel personnel) where,
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      repo.findUser(
        userId,
        exclude: exclude,
        where: where,
      );

  /// Stream of changes on given [personnel]
  Stream<Personnel> onChanged(Personnel personnel) => where(
        (state) =>
            (state is PersonnelUpdated && state.data.uuid == personnel.uuid) ||
            (state is PersonnelsLoaded && state.data.contains(personnel.uuid)),
      ).map((state) => state is PersonnelsLoaded ? repo[personnel.uuid] : state.data);

  /// Get count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      repo.count(exclude: exclude);

  void _assertState() {
    if (operationBloc.isUnselected) {
      throw PersonnelBlocException(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'PersonnelBloc.load()'",
        state,
      );
    }
  }

  String _assertData(Personnel personnel) {
    if (personnel?.uuid == null) {
      throw ArgumentError(
        "Personnel have no uuid",
      );
    }
    TrackingUtils.assertRef(personnel);
    return AffiliationUtils.assertRef(personnel);
  }

  /// Fetch personnel from [service]
  Future<List<Personnel>> load() async {
    _assertState();
    return dispatch<List<Personnel>>(
      LoadPersonnels(ouuid ?? operationBloc.selected.uuid),
    );
  }

  /// Mobilize authenticated user for
  Future<Personnel> mobilizeUser() async {
    _assertState();
    final user = affiliationBloc.users.user;
    if (user == null) {
      throw StateError("No user authenticated");
    }
    var personnels = findUser(
      user.userId,
      exclude: const [],
    );
    // Choose mobilized personnels over retired
    final existing = personnels.firstWhere(
      (p) => p.status != PersonnelStatus.retired,
      orElse: () => personnels.firstOrNull,
    );
    if (existing == null) {
      final affiliation = affiliationBloc.findUserAffiliation();
      final personnel = await create(PersonnelModel(
        uuid: Uuid().v4(),
        person: PersonModel(
          uuid: affiliation.person?.uuid,
          userId: user.userId,
          fname: user.fname,
          lname: user.lname,
          phone: user.phone,
          email: user.email,
          temporary: affiliation.isTemporary,
        ),
        status: PersonnelStatus.alerted,
        affiliation: affiliation.toRef(),
        tracking: TrackingUtils.newRef(),
      ));
      return personnel;
    } else if (existing.status != PersonnelStatus.alerted) {
      return update(existing.copyWith(
        status: PersonnelStatus.alerted,
      ));
    }
    // Already mobilized
    return existing;
  }

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) {
    _assertState();
    _assertData(personnel);
    return dispatch<Personnel>(
      CreatePersonnel(
        ouuid ?? operationBloc.selected.uuid,
        personnel.copyWith(
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
      UnloadPersonnels(ouuid),
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
    if (personnels.isNotEmpty) {
      try {
        await affiliationBloc.fetch(
          personnels.map((p) => p.affiliation.uuid),
        );
      } on Exception catch (e) {
        print(e);
      }
    }
    return toOK(
      command,
      PersonnelsLoaded(repo.keys),
      result: personnels,
    );
  }

  Future<PersonnelState> _create(CreatePersonnel command) async {
    final auuid = _assertData(command.data);
    if (!affiliationBloc.repo.containsKey(auuid)) {
      var affiliation = affiliationBloc.findPersonnelAffiliation(command.data);
      if (!affiliation.isAffiliate) {
        await affiliationBloc.temporary(
          command.data,
          affiliation.copyWith(
            person: command.data.person.toRef(),
          ),
        );
      }
    }
    final affiliation = affiliationBloc.repo[auuid];
    final person = affiliationBloc.persons[affiliation.person.uuid];
    final personnel = await repo.create(
      command.ouuid,
      // Update with current person
      command.data.withPerson(person),
    );
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
    final personnels = await repo.close();
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
          final next = current.mergeWith(event.data.json);
          repo.replace(
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
        stackTrace: stackTrace ?? StackTrace.current,
      );

  @override
  Future<void> close() async {
    super.close();
    await repo.dispose();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class PersonnelCommand<S, T> extends BlocCommand<S, T> {
  PersonnelCommand(S data, [props = const []]) : super(data, props);
}

class LoadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  LoadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => 'LoadPersonnels {ouuid: $data}';
}

class CreatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  final String ouuid;
  CreatePersonnel(this.ouuid, Personnel data) : super(data);

  @override
  String toString() => 'CreatePersonnel {ouuid: $ouuid, personnel: $data}';
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
  UnloadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => 'UnloadPersonnels {ouuid: $data}';
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
  bool isRetired() => (data is Personnel) ? (data as Personnel).status == PersonnelStatus.retired : false;
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
