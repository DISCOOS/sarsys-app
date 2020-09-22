import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/utils/data.dart';
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
import 'package:SarSys/features/user/domain/entities/User.dart';
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
        ConnectionAwareBloc<String, Personnel> {
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
      // Handle
      _processPersonConflicts,
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
        await onLoadedAsync();
        await mobilizeUser();
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

  void _processPersonConflicts(StorageTransition<Person> event) {
    try {
      if (PersonRepository.isDuplicateUser(event)) {
        // Find current person usages and replace them with existing user
        final duplicate = event.from.value.uuid;
        final existing = PersonModel.fromJson(event.conflict.base);
        find(
          where: (personnel) => personnel.person?.uuid == duplicate,
        ).map((personnel) => personnel.withPerson(existing)).forEach(update);
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

  /// Get all [Personnel]s
  Iterable<Personnel> get values => repo.values;

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

  /// Find [Personnel]s matching given query
  Iterable<Personnel> find({bool where(Personnel personnel)}) => repo.find(where: where);

  /// Check if user is mobilized
  bool isUserMobilized() => findUser().any((p) => p.isMobilized);

  /// Get mobilized user if found.
  ///
  /// Otherwise get a suitable
  /// personnel previously retired
  /// if found. If more then one
  /// retired personnel for given
  /// user was found, select an
  /// affiliation matching active
  /// affiliation for current user
  Personnel findMobilizedUserOrReuse({
    String userId,
    bool Function(Personnel personnel) where,
  }) {
    final personnels = findUser(
      where: where,
      userId: userId,
      exclude: const [],
    );
    final mobilized = personnels.where(
      (p) => p.status != PersonnelStatus.retired,
    );
    final match = affiliationBloc.findUserAffiliation(
      userId: userId,
    );

    // Try to match active affiliation
    // with previous affiliations
    final candidates = mobilized.isNotEmpty
        ? [Pair<Personnel, int>.of(mobilized.first, 0)]
        : personnels.fold(
            <Pair<Personnel, int>>[],
            (candidates, p) {
              var rank = 0;
              final next = affiliationBloc.repo[p.affiliation?.uuid];
              if (next != null) {
                if (next.org?.uuid != match.org?.uuid) rank++;
                if (next.div?.uuid != match.div?.uuid) rank++;
                if (next.dep?.uuid != match.dep?.uuid) rank++;
              }
              return candidates
                ..add(
                  Pair<Personnel, int>.of(p, rank),
                );
            },
          );

    // Choose personnel with highest rank
    final found = sortList<Pair<Personnel, int>>(
      candidates,
      (a, b) => a.right - b.right,
    ).firstOrNull?.left;

    return found;
  }

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
    return dispatch<List<Personnel>>(
      LoadPersonnels(ouuid),
    );
  }

  /// Mobilize authenticated user for
  Future<Personnel> mobilizeUser() async {
    return dispatch<Personnel>(
      MobilizeUser(ouuid, affiliationBloc.users.user),
    );
  }

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) async {
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
  Future<Personnel> update(Personnel personnel) async {
    return dispatch<Personnel>(
      UpdatePersonnel(personnel),
    );
  }

  /// Delete given personnel
  Future<Personnel> delete(String uuid) async {
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
    } else if (command is MobilizeUser) {
      yield* _mobilize(command);
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
    final onPersonnels = Completer<Iterable<Personnel>>();
    var personnels = await repo.load(
      command.data,
      onRemote: onPersonnels,
    );

    if (personnels.isNotEmpty) {
      await affiliationBloc.fetch(
        personnels.map((p) => p.affiliation.uuid),
      );
    }
    yield toOK(
      command,
      PersonnelsLoaded(repo.keys),
      result: personnels.map(_withPerson).toList(),
    );

    // Notify when all states was fetched from remote storage
    onComplete(
      [
        onPersonnels.future,
        if (personnels.isNotEmpty) onAffiliationState<AffiliationsFetched>(),
      ],
      toState: (results) {
        return PersonnelsLoaded(
          repo.keys,
          isRemote: true,
        );
      },
      toCommand: (state) => _StateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<AffiliationState> onAffiliationState<T extends AffiliationState>({bool isRemote = true}) =>
      affiliationBloc.where((s) => s.isRemote == isRemote && s is T).first;

  Stream<PersonnelState> _mobilize(MobilizeUser command) async* {
    final user = command.user;
    if (user != null) {
      var found = findMobilizedUserOrReuse(
        userId: user.userId,
      );
      if (found == null) {
        final affiliation = affiliationBloc.findUserAffiliation();
        found = PersonnelModel(
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
        );
        yield* _create(CreatePersonnel(
          command.data,
          found,
        ));
      } else if (found.isMobilized != true) {
        yield* _update(UpdatePersonnel(found.copyWith(
          status: PersonnelStatus.alerted,
        )));
      }
      yield toOK(
        command,
        UserMobilized(user, found),
        result: found,
      );
    }
  }

  Stream<PersonnelState> _create(CreatePersonnel command) async* {
    Affiliation affiliation = await _ensureAffiliation(command);
    final person = affiliationBloc.persons[affiliation.person.uuid];
    final personnel = repo.apply(
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
        affiliation = await affiliationBloc.temporary(
          command.data,
          affiliation.copyWith(
            person: command.data.person,
          ),
        );
      }
      return affiliation;
    }
    return affiliationBloc.repo[auuid];
  }

  Stream<PersonnelState> _update(UpdatePersonnel command) async* {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final personnel = repo.apply(command.data);
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
    final onRemote = Completer<Personnel>();
    final personnel = repo.delete(
      command.data.uuid,
      onResult: onRemote,
    );
    yield toOK(
      command,
      PersonnelDeleted(personnel),
      result: personnel,
    );

    // Notify when all states are remote
    onComplete(
      [onRemote.future],
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

  Future<PersonnelState> _unload(PersonnelCommand command, {dynamic result}) async {
    final personnels = await repo.close();
    return toOK(
      command,
      PersonnelsUnloaded(personnels),
      result: result ?? personnels,
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

  Personnel _withPerson(Personnel personnel) {
    final puuid = personnel.person?.uuid;
    return puuid == null ? personnel : personnel.withPerson(affiliationBloc.persons[puuid]);
  }

  @override
  Future<void> close() async {
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
  LoadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}

class MobilizeUser extends PersonnelCommand<String, Personnel> {
  MobilizeUser(String ouuid, this.user) : super(ouuid);
  final User user;

  @override
  String toString() => '$runtimeType {ouuid: $data, user: $user}';
}

class CreatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  final String ouuid;
  CreatePersonnel(this.ouuid, Personnel data) : super(data);

  @override
  String toString() => '$runtimeType {ouuid: $ouuid, personnel: $data}';
}

class UpdatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  UpdatePersonnel(Personnel data) : super(data);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class DeletePersonnel extends PersonnelCommand<Personnel, Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class _InternalMessage extends PersonnelCommand<PersonnelMessage, PersonnelMessage> {
  _InternalMessage(PersonnelMessage data) : super(data);

  @override
  String toString() => '$runtimeType {message: $data}';
}

class UnloadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  UnloadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
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
  bool isUserMobilized() => this is UserMobilized;
  bool isUnloaded() => this is PersonnelsUnloaded;

  bool isStatusChanged() => false;
  bool isMobilized() => (data is Personnel) ? (data as Personnel).isMobilized : false;
  bool isTracked() => (data is Personnel) ? (data as Personnel).tracking?.uuid != null : false;
  bool isRetired() => (data is Personnel) ? (data as Personnel).status == PersonnelStatus.retired : false;
}

class PersonnelsEmpty extends PersonnelState<Null> {
  PersonnelsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class PersonnelsLoaded extends PersonnelState<List<String>> {
  PersonnelsLoaded(
    List<String> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {personnels: $data, isRemote: $isRemote}';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => '$runtimeType {personnel: $data, isRemote: $isRemote}';
}

class UserMobilized extends PersonnelState<Personnel> {
  UserMobilized(
    this.user,
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  final User user;

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => '$runtimeType {personnel: $data, user: $user, isRemote: $isRemote}';
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
  String toString() => '$runtimeType {data: $data, previous: $previous, isRemote: $isRemote}';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

class PersonnelsUnloaded extends PersonnelState<List<Personnel>> {
  PersonnelsUnloaded(List<Personnel> personnel) : super(personnel);

  @override
  String toString() => '$runtimeType {data: $data}';
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
