import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
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
  PersonnelBloc(this.repo, this.affiliationBloc, this.operationBloc, BlocEventBus bus) : super(bus: bus) {
    assert(repo != null, "repo can not be null");
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(affiliationBloc != null, "affiliationBloc can not be null");

    // Load and unload personnels as needed
    subscribe<OperationUpdated>(_processOperationState);
    subscribe<OperationSelected>(_processOperationState);
    subscribe<OperationUnselected>(_processOperationState);
    subscribe<OperationDeleted>(_processOperationState);

    // Update from messages pushed from backend
    registerStreamSubscription(service.messages.listen(
      _processPersonnelMessage,
    ));

    registerStreamSubscription(affiliationBloc.persons.onChanged.listen(
      // Handle person changes
      _processPersonChanged,
    ));
  }

  /// Process [OperationState] events
  ///
  /// Invokes [load] and [unload] as needed.
  ///
  void _processOperationState(BaseBloc bloc, OperationState state) async {
    // Only process local events
    if (isOpen && state.isLocal) {
      final unselected = (bloc as OperationBloc).isUnselected;
      if (state.shouldLoad(ouuid)) {
        await dispatch(LoadPersonnels(
          state.data.uuid,
        ));
        // Could change during load
        if ((bloc as OperationBloc).isSelected && state.isSelected()) {
          await mobilizeUser();
        }
      } else if (isReady && (unselected || state.shouldUnload(ouuid))) {
        await unload();
      }
    }
  }

  /// Process [PersonnelMessage] events
  ///
  /// Schedules [_InternalMessage].
  ///
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

  void _processPersonChanged(StorageTransition<Person> state) {
    try {
      if (PersonRepository.isDuplicateUser(state)) {
        // Find current person usages and replace with existing user
        final duplicate = state.to.value.uuid;
        final existing = state.conflict.base;
        findUser(
          userId: duplicate,
          exclude: [],
        ).map((personnel) => personnel.mergeWith({"person": existing})).forEach(update);
      } else {
        findUser(
          userId: state.to.value.uuid,
          exclude: [],
        ).map((personnel) => personnel.withPerson(state.from.value)).forEach(
              (personnel) => repo.replace(personnel),
            );
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

  /// Check if bloc is ready
  bool get isReady => repo.isReady;

  /// Get uuid of [Operation] that manages personnels in [repo]
  String get ouuid => isReady ? repo.ouuid ?? operationBloc.selected?.uuid : null;

  @override
  PersonnelState get initialState => PersonnelsEmpty();

  /// Get [Personnel] from [puuids]
  Iterable<Aggregate> from(List<String> puuids) =>
      puuids.where((puuid) => repo.containsKey(puuid)).map((puuid) => repo[puuid]).toList();

  /// Check if given [Personnel.uuid] is current user
  bool isUser(String uuid) => repo[uuid]?.userId == operationBloc.userBloc.userId;

  /// Find [Personnel] from [user]
  Iterable<Personnel> findUser({
    String userId,
    bool Function(Personnel personnel) where,
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      repo.findUser(
        userId ?? operationBloc.userBloc.userId,
        where: where,
        exclude: exclude,
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
        "No operation selected. "
        "Ensure that 'OperationBloc.select(String id)' is called before 'PersonnelBloc.load()'",
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
      LoadPersonnels(ouuid),
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
      userId: user.userId,
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
          temporary: affiliation.isUnorganized,
        ),
        status: PersonnelStatus.alerted,
        affiliation: affiliation.toRef(),
        tracking: TrackingUtils.newRef(),
      ));
      return personnel;
    } else if (existing.status == PersonnelStatus.retired) {
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
        ouuid,
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
    return dispatch<List<Personnel>>(
      UnloadPersonnels(ouuid),
    );
  }

  @override
  Stream<PersonnelState> execute(PersonnelCommand command) async* {
    if (command is LoadPersonnels) {
      yield* _load(command);
    } else if (command is CreatePersonnel) {
      yield* _create(command);
    } else if (command is UpdatePersonnel) {
      yield* _update(command);
    } else if (command is DeletePersonnel) {
      yield* _delete(command);
    } else if (command is UnloadPersonnels) {
      yield await _unload(command);
    } else if (command is _InternalMessage) {
      yield await _process(command);
    } else if (command is _StateChange) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<PersonnelState> _load(LoadPersonnels command) async* {
    // Fetch cached and handle
    // response from remote when ready
    final onRemote = Completer<Iterable<Personnel>>();
    var personnels = await repo.load(
      command.data,
      onRemote: onRemote,
    );

    if (personnels.isNotEmpty) {
      // Only wait for cached only.
      // Remote states are published by
      // AffiliationsLoaded later which
      // this method is not dependent on
      await affiliationBloc.fetch(
        personnels.map((p) => p.affiliation.uuid),
      );
    }
    yield toOK(
      command,
      PersonnelsLoaded(repo.keys),
      result: personnels,
    );

    // Notify when states was fetched from remote storage
    onComplete(
      [onRemote.future],
      toState: (_) => PersonnelsLoaded(
        repo.keys,
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

  Stream<PersonnelState> _create(CreatePersonnel command) async* {
    Affiliation affiliation = await _ensureAffiliation(command);
    final person = affiliationBloc.persons[affiliation.person.uuid];
    final personnel = await repo.apply(
      // Update with current person
      command.data.withPerson(person),
    );
    yield toOK(
      command,
      PersonnelCreated(personnel),
      result: personnel,
    );

    // Notify when all states are remote
    onComplete(
      [
        affiliationBloc.repo.onRemote(affiliation.uuid),
        affiliationBloc.persons.onRemote(person.uuid),
        repo.onRemote(personnel.uuid),
      ],
      toState: (_) => PersonnelCreated(
        personnel,
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

  Future<Affiliation> _ensureAffiliation(CreatePersonnel command) async {
    final auuid = _assertData(command.data);
    if (!affiliationBloc.repo.containsKey(auuid)) {
      var affiliation = affiliationBloc.findPersonnelAffiliation(command.data);
      if (!affiliation.isAffiliate) {
        await affiliationBloc.temporary(
          command.data,
          affiliation.copyWith(
            person: command.data.person?.toRef(),
          ),
        );
      }
    }
    return affiliationBloc.repo[auuid];
  }

  Stream<PersonnelState> _update(UpdatePersonnel command) async* {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final personnel = await repo.apply(command.data);
    yield toOK(
      command,
      PersonnelUpdated(personnel, previous),
      result: personnel,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(personnel.uuid)],
      toState: (_) => PersonnelUpdated(
        personnel,
        previous,
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

  Stream<PersonnelState> _delete(DeletePersonnel command) async* {
    _assertData(command.data);
    final personnel = await repo.delete(command.data.uuid);
    yield toOK(
      command,
      PersonnelDeleted(personnel),
      result: personnel,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(personnel.uuid, require: false)],
      toState: (_) => PersonnelDeleted(
        personnel,
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
          final next = PersonnelModel.fromJson(event.data.json);
          repo.patch(next);
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

class _StateChange extends PersonnelCommand<PersonnelState, Personnel> {
  _StateChange(
    PersonnelState state,
  ) : super(state);

  @override
  String toString() => '$runtimeType {state: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class PersonnelState<T> extends BlocEvent<T> {
  PersonnelState(
    T data, {
    StackTrace stackTrace,
    props = const [],
    this.isRemote = false,
  }) : super(data, props: [...props, isRemote], stackTrace: stackTrace);

  final bool isRemote;
  bool get isLocal => !isRemote;

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
  PersonnelsLoaded(
    List<String> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => 'PersonnelCreated {data: $data, isRemote: $isRemote}';
}

class PersonnelUpdated extends PersonnelState<Personnel> {
  final Personnel previous;
  PersonnelUpdated(
    Personnel data,
    this.previous, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [previous]);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  bool isStatusChanged() => data.status != previous.status;

  @override
  String toString() => 'PersonnelUpdated {data: $data, previous: $previous, isRemote: $isRemote}';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => 'PersonnelDeleted {data: $data, isRemote: $isRemote}';
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
