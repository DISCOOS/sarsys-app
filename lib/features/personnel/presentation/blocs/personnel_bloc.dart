import 'dart:async';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';

typedef void PersonnelCallback(VoidCallback fn);

class PersonnelBloc
    extends StatefulBloc<PersonnelCommand, PersonnelState, PersonnelBlocError, String, Personnel, PersonnelService>
    with
        LoadableBloc<List<Personnel>>,
        CreatableBloc<Personnel>,
        UpdatableBloc<Personnel>,
        DeletableBloc<Personnel>,
        UnloadableBloc<List<Personnel>> {
  ///
  /// Default constructor
  ///
  PersonnelBloc(
    this.repo,
    this.affiliationBloc,
    this.operationBloc,
    BlocEventBus bus,
  ) : super(bus: bus) {
    assert(repo != null, "repo can not be null");
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(affiliationBloc != null, "affiliationBloc can not be null");

    // Load and unload personnels as needed
    subscribe<OperationUpdated>(_processOperationState);
    subscribe<OperationSelected>(_processOperationState);
    subscribe<OperationUnselected>(_processOperationState);
    subscribe<OperationDeleted>(_processOperationState);

    // Notify when personnel state has changed
    forward(
      (t) => _NotifyPersonnelStateChanged(t),
    );
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
        await mobilizeUser();
      } else if (isReady && (unselected || state.shouldUnload(ouuid))) {
        await unload();
      }
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
  Iterable<StatefulRepository> get repos => [repo];

  /// Get [Personnel] from [uuid]
  Personnel operator [](String uuid) => repo[uuid];

  /// Get [PersonnelService]
  PersonnelService get service => repo.service;

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

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
      throw ArgumentError("Personnel have no uuid");
    }
    if (personnel?.operation?.uuid == null) {
      throw ArgumentError(
        "Personnel ${personnel.uuid} have no operation uuid",
      );
    }
    if (personnel?.operation?.uuid != ouuid) {
      throw ArgumentError(
        "Personnel ${personnel.uuid} is not mobilized for operation $ouuid",
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

  /// Check if mobilization in progress
  bool get isUserMobilizing => _mobilizing != null;
  Future<Personnel> _mobilizing;

  /// Check if user is mobilized
  bool get isUserMobilized => findUser().any((p) => p.isMobilized);

  /// Mobilize authenticated user for
  Future<Personnel> mobilizeUser() async {
    await onLoadedAsync();
    final found = findMobilizedUserOrReuse(
      userId: affiliationBloc.users.userId,
    );
    if (found?.isMobilized == true) {
      return found;
    } else if (isUserMobilizing) {
      return _mobilizing.timeout(
        const Duration(seconds: 5),
      );
    }
    try {
      _mobilizing = dispatch<Personnel>(
        MobilizeUser(ouuid, affiliationBloc.users.user),
      );
      return await _mobilizing;
    } finally {
      _mobilizing = null;
    }
  }

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) async {
    _assertData(personnel);
    return dispatch<Personnel>(
      CreatePersonnel(
        ouuid,
        personnel,
      ),
    );
  }

  /// Update given personnel
  Future<Personnel> update(Personnel personnel) async {
    await onLoadedAsync();
    return dispatch<Personnel>(
      UpdatePersonnel(personnel),
    );
  }

  /// Delete given personnel
  Future<Personnel> delete(String uuid) async {
    await onLoadedAsync();
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
    } else if (command is _NotifyPersonnelStateChanged) {
      yield await _notify(command);
    } else if (command is _NotifyBlocStateChange) {
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
        if (personnels.isNotEmpty) _onAffiliationState<AffiliationsFetched>(),
      ],
      toState: (results) {
        return PersonnelsLoaded(
          repo.keys,
          isRemote: true,
        );
      },
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<AffiliationState> _onAffiliationState<T extends AffiliationState>({bool isRemote = true}) =>
      affiliationBloc.where((s) => s.isRemote == isRemote && s is T).first;

  Stream<PersonnelState> _mobilize(MobilizeUser command) async* {
    final user = command.user;
    assert(user != null, 'Command $command have noe user given');
    if (user != null) {
      var found = findMobilizedUserOrReuse(
        userId: user.userId,
      );
      if (found == null) {
        final affiliation = affiliationBloc.findUserAffiliation();
        found = PersonnelModel(
          uuid: Uuid().v4(),
          affiliation: affiliation.copyWith(
            person: PersonModel(
              uuid: affiliation.person?.uuid,
              userId: user.userId,
              fname: user.fname,
              lname: user.lname,
              phone: user.phone,
              email: user.email,
              temporary: affiliation.isUnorganized,
            ),
          ),
          status: PersonnelStatus.alerted,
          tracking: TrackingUtils.newRef(),
          operation: AggregateRef.fromType(ouuid),
        );
        yield* _create(
          CreatePersonnel(
            command.data,
            found,
            callback: command.callback,
          ),
          toState: (Personnel personnel, bool isRemote) => UserMobilized(
            user,
            personnel,
            isRemote: isRemote,
          ),
        );
      } else if (found.isMobilized != true) {
        yield* _update(UpdatePersonnel(
          found.copyWith(
            status: PersonnelStatus.alerted,
          ),
          callback: command.callback,
        ));
      } else {
        yield toOK(
          command,
          UserMobilized(
            user,
            found,
            isRemote: repo.getState(found.uuid).isRemote,
          ),
          result: found,
        );
      }
    }
  }

  Stream<PersonnelState> _create(
    CreatePersonnel command, {
    PersonnelState Function(Personnel personnel, bool isRemote) toState,
  }) async* {
    // Prepare
    _assertData(command.data);
    toState ??= (Personnel personnel, bool isRemote) => PersonnelCreated(
          personnel,
          isRemote: isRemote,
        );

    // Apply
    final personnel = repo.apply(
      _ensureAffiliation(command.data),
    );

    // Notify local change
    yield toOK(
      command,
      toState(personnel, false),
      result: personnel,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(personnel.uuid)],
      toState: (results) {
        final state = results.whereType<StorageState<Personnel>>().first;
        return toState(
          state.value,
          state.isRemote,
        );
      },
      toCommand: (state) => _NotifyBlocStateChange(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Personnel _ensureAffiliation(Personnel personnel) {
    if (personnel.affiliation.isAffiliate != true) {
      final auuid = personnel.affiliation.uuid;
      final affiliation = affiliationBloc.repo[auuid] ??
          affiliationBloc.findPersonnelAffiliation(
            personnel,
          );
      return personnel.copyWith(
        affiliation: affiliation,
      );
    }
    return personnel;
  }

  Stream<PersonnelState> _update(UpdatePersonnel command) async* {
    _assertData(command.data);
    final previous = repo[command.data.uuid];
    final personnel = repo.apply(
      // Update with current person
      _ensureAffiliation(command.data),
    );
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
      toCommand: (state) => _NotifyBlocStateChange(state),
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
      toCommand: (state) => _NotifyBlocStateChange(state),
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

  Future<PersonnelState> _notify(_NotifyPersonnelStateChanged command) async {
    final personnel = command.personnel;

    if (command.isCreated) {
      return toOK(
        command,
        PersonnelCreated(
          personnel,
          isRemote: command.isRemote,
        ),
        result: personnel,
      );
    }

    if (command.isUpdated) {
      return toOK(
        command,
        PersonnelUpdated(
          personnel,
          command.previous,
          isRemote: command.isRemote,
        ),
        result: personnel,
      );
    }

    assert(command.isDeleted);

    return toOK(
      command,
      PersonnelDeleted(
        personnel,
        isRemote: command.isRemote,
      ),
      result: personnel,
    );
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
}

/// ---------------------
/// Commands
/// ---------------------
abstract class PersonnelCommand<S, T> extends BlocCommand<S, T> {
  PersonnelCommand(
    S data, {
    props = const [],
    Completer<T> callback,
  }) : super(data, props, callback);
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
  CreatePersonnel(
    this.ouuid,
    Personnel data, {
    Completer<Personnel> callback,
  }) : super(data, callback: callback);

  final String ouuid;

  @override
  String toString() => '$runtimeType {ouuid: $ouuid, personnel: $data}';
}

class UpdatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  UpdatePersonnel(
    Personnel data, {
    Completer<Personnel> callback,
  }) : super(data, callback: callback);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class DeletePersonnel extends PersonnelCommand<Personnel, Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class _NotifyPersonnelStateChanged extends PersonnelCommand<StorageTransition<Personnel>, Personnel> {
  _NotifyPersonnelStateChanged(
    StorageTransition<Personnel> transition,
  ) : super(transition);

  Personnel get personnel => data.to.value;
  Personnel get previous => data.from?.value;

  bool get isCreated => data.isCreated;
  bool get isUpdated => data.isChanged;
  bool get isDeleted => data.isDeleted;

  bool get isRemote => data.to?.isRemote == true;

  @override
  String toString() => '$runtimeType {previous: $data, next: $data}';
}

class UnloadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  UnloadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}

class _NotifyBlocStateChange extends PersonnelCommand<PersonnelState, Personnel> {
  _NotifyBlocStateChange(
    PersonnelState state,
  ) : super(state);

  @override
  String toString() => '$runtimeType {state: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------

abstract class PersonnelState<T> extends PushableBlocEvent<T> {
  PersonnelState(
    T data, {
    StackTrace stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

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

class UserMobilized extends PersonnelCreated {
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
