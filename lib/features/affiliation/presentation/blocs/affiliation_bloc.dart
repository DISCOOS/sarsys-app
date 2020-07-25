import 'dart:async';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/OperationalFunction.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Business Logic Component for Affiliation
///
/// The main purpose of this BLoC it to minimize
/// the amount of personal identifiable information
/// (PII) fetched and stored to local storage.
///
/// Fetching all affiliations is not possible
/// by design. It would potentially violate
/// Article 5 (Chapter II) in the European
/// general data protection law, which mandates
/// data minimization.
///
/// Instead, PII is only fetched in context of
/// an operation using the 'expand' query parameter
/// supported by 'GET /api/operations/{uuid}/personnels'.
///
/// New users are onboarded based on claims in
/// access-tokens. Users without any
/// affiliation with an organisations are
/// onboarded as temporary Persons. If the same
/// physical person signs in with multiple
/// accounts, an new Person will be onboarded
/// for each account, leading to Person duplicates
///
class AffiliationBloc extends BaseBloc<AffiliationCommand, AffiliationState, AffiliationBlocError>
    with LoadableBloc<List<Affiliation>>, UnloadableBloc<List<Affiliation>>, ConnectionAwareBloc {
  ///
  /// Default constructor
  ///
  AffiliationBloc({
    @required this.users,
    @required this.repo,
    @required BlocEventBus bus,
  }) : super(bus: bus) {
    assert(this.orgs != null, "organisations repository can not be null");
    assert(this.divs != null, "divisions repository can not be null");
    assert(this.deps != null, "departments repository can not be null");
    assert(this.users != null, "userBloc can not be null");
    assert(this.persons != null, "persons repository can not be null");
    assert(this.repo != null, "affiliations repository can not be null");
    assert(this.orgs.service != null, "organisations service can not be null");
    assert(this.divs.service != null, "divisions service can not be null");
    assert(this.deps.service != null, "departments service can not be null");
    assert(this.persons.service != null, "departments service can not be null");
    assert(this.repo.service != null, "departments service can not be null");

    registerStreamSubscription(users.listen(
      // Load and unload repos as needed
      _processUserState,
    ));

    registerStreamSubscription(persons.onChanged.listen(
      // Handle
      _processPersonConflicts,
    ));
  }

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [
        orgs,
        divs,
        deps,
        repo,
        persons,
      ];

  /// Get [OrganisationRepository]
  OrganisationRepository get orgs => repo.orgs;

  /// Get [DivisionRepository]
  DivisionRepository get divs => repo.divs;

  /// Get [DepartmentRepository]
  DepartmentRepository get deps => repo.deps;

  /// Get [PersonRepository]
  PersonRepository get persons => repo.persons;

  /// Get [AffiliationRepository]
  final AffiliationRepository repo;

  /// Get [UserBloc]
  final UserBloc users;

  void _processUserState(UserState state) async {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad() && !repo.isReady) {
          // Wait for load before onboarding user
          await dispatch(LoadAffiliations());
          onboard();
        } else if (state.shouldUnload() && repo.isReady) {
          dispatch(UnloadAffiliations());
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

  void _processPersonConflicts(StorageTransition<Person> event) {
    try {
      if (PersonRepository.isDuplicateUser(event)) {
        // Find current person usages and replace then with existing user
        final duplicate = event.from.value.uuid;
        final existing = event.conflict.base.elementAt<String>('uuid');
        find(
          where: (affiliation) => affiliation.person.uuid == duplicate,
        ).map((affiliation) => affiliation.copyWith(person: affiliation.person.cast(uuid: existing))).forEach(update);
        // Remove duplicate person
        persons.delete(duplicate);
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

  /// Check if bloc is ready
  bool get isReady => repo.isReady;

  @override
  AffiliationsEmpty get initialState => AffiliationsEmpty();

  /// Get searchable string from [Affiliation.uuid]
  String toSearchable(String uuid) {
    final affiliation = repo[uuid];
    if (affiliation?.person?.uuid != null) {
      final person = persons[affiliation.person.uuid];
      return "${person?.searchable} ${affiliation?.searchable}";
    }
    return "${affiliation?.searchable ?? ''}";
  }

  /// Find [Affiliation]s matching given  query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)}) => repo.find(where: where);

  /// Find [Affiliation]s matching given  query
  Iterable<Affiliation> findPerson(String puuid) => repo.findPerson(puuid);

  /// Get entity as [Affiliation] from device number
  Affiliation findEntity(String number) {
    final org = findOrganisation(number);
    final div = findDivision(number);
    final dep = findDepartment(number);
    return AffiliationModel(
      org: org?.toRef(),
      div: div?.toRef(),
      dep: dep?.toRef(),
    );
  }

  /// Get full affiliation name as comma-separated list of organisation, division and department names
  String findEntityName(String number, {String empty = 'Ingen'}) {
    final names = [
      findOrganisation(number)?.name,
      findDivision(number)?.name,
      findDepartment(number)?.name,
    ]..removeWhere((name) => name == null);
    return names.isEmpty ? empty : names.join(', ');
  }

  /// Get full affiliation name as comma-separated list of organisation, division and department names
  String toName(
    Affiliation affiliation, {
    String empty = 'Ingen',
    bool short = false,
  }) {
    final names = [
      orgs[affiliation?.org?.uuid]?.name,
      divs[affiliation?.div?.uuid]?.name,
      deps[affiliation?.dep?.uuid]?.name,
    ]..removeWhere((name) => name == null);
    return names.isEmpty ? empty : short ? names.last : names.join(', ');
  }

  /// Get [Person] from User
  Person findUserPerson({String userId}) => persons.findUser(userId ?? users.user.userId);

  /// Get Affiliation from User
  Affiliation findUserAffiliation({
    String userId,
    bool ensure = true,
    AffiliationType defaultType = AffiliationType.volunteer,
    AffiliationStandbyStatus defaultStatus = AffiliationStandbyStatus.available,
  }) {
    final _userId = userId ?? users.userId;
    final person = findUserPerson(userId: _userId);
    if (person != null) {
      final affiliation = repo.findPerson(person.uuid).firstOrNull;
      if (affiliation != null) {
        return affiliation;
      }
    }
    final org = findUserOrganisation(userId: userId);
    final div = findUserDivision(userId: userId);
    final dep = findUserDepartment(userId: userId);
    final affiliation = AffiliationModel(
      uuid: Uuid().v4(),
      type: defaultType,
      org: org?.toRef(),
      div: div?.toRef(),
      dep: dep?.toRef(),
      status: defaultStatus,
      person: person?.toRef(),
    );
    return ensure || !affiliation.isEmpty ? affiliation : null;
  }

  /// Get [Affiliation] from [Personnel].
  /// Throws an [ArgumentError] if [Personnel] does
  /// not contain a reference to an [Affiliation]
  Affiliation findPersonnelAffiliation(
    Personnel personnel, {
    bool ensure = true,
    AffiliationType defaultType = AffiliationType.volunteer,
    AffiliationStandbyStatus defaultStatus = AffiliationStandbyStatus.available,
  }) =>
      repo[personnel?.affiliation?.uuid] ??
      (personnel.userId != null
          ? findUserAffiliation(
              ensure: ensure,
              userId: personnel.userId,
              defaultType: defaultType,
              defaultStatus: defaultStatus,
            )?.copyWith(
              uuid: AffiliationUtils.assertRef(personnel),
            )
          : (ensure
              ? AffiliationModel(
                  type: defaultType,
                  status: defaultStatus,
                  uuid: AffiliationUtils.assertRef(personnel),
                )
              : null));

  /// Get [Organisation] from User
  Organisation findUserOrganisation({String userId}) {
    final div = findUserDivision(userId: userId);
    return orgs[div?.organisation?.uuid];
  }

  /// Get Division from User
  Division findUserDivision({String userId}) {
    final user = users.repo[userId] ?? users.user;
    final name = (user ?? users.user).division?.toLowerCase();
    return divs.values
        .where(
          (division) => division.name.toLowerCase() == name,
        )
        ?.firstOrNull;
  }

  /// Get Department id from User
  Department findUserDepartment({String userId}) {
    final user = users.repo[userId] ?? users.user;
    final name = (user ?? users.user).department?.toLowerCase();
    return deps.values
        .where(
          (department) => department.name.toLowerCase() == name,
        )
        ?.firstOrNull;
  }

  /// Get Organisation from [FleetMap] number
  Organisation findOrganisation(String number) {
    String prefix = AffiliationUtils.toPrefix(number);
    if (prefix != null) {
      return orgs.values
          .where(
            (division) => division.prefix == prefix,
          )
          .firstOrNull;
    }
    return null;
  }

  /// Get Division from [FleetMap] number
  Division findDivision(String number) {
    String suffix = AffiliationUtils.toSuffix(number);
    if (suffix != null) {
      return divs.values
          .where(
            (division) => division.suffix == suffix,
          )
          .firstOrNull;
    }
    return null;
  }

  /// Get Department from device number
  Department findDepartment(String number) {
    String suffix = AffiliationUtils.toSuffix(number);
    if (suffix != null) {
      return deps.values
          .where(
            (department) => department.suffix == suffix,
          )
          .firstOrNull;
    }
    return null;
  }

  /// Get function from device number
  OperationalFunction findFunction(String number) {
    final org = findOrganisation(number);
    return AffiliationUtils.findFunction(org.fleetMap, number);
  }

  /// Get [AffiliationQuery] object from current state
  AffiliationQuery query() => AffiliationQuery(
        this,
        aggregates: AffiliationQuery.toAggregates(this),
      );

  /// Get all affiliated [Person]s as [Affiliation]
  Iterable<Affiliation> get affiliates => query().affiliates;

  /// Get all entities as [Affiliation]s from current state
  Iterable<Affiliation> get entities => query().find(
        types: [OrganisationModel, DivisionModel, DepartmentModel],
      );

  /// Get divisions in given [Organisation] sorted on [Division.name]
  Iterable<Division> getDivisions(String orguuid) {
    final org = orgs[orguuid];
    if (org != null) {
      final divisions = Map.fromEntries(org.divisions.map((uuid) => MapEntry(uuid, divs[uuid])));
      return sortMapValues<String, Division, String>(
        divisions ?? <String, Division>{},
        (division) => division.name,
      ).values;
    }
    return [];
  }

  /// Get departments in given [Division] sorted on [Department.name]
  Iterable<Department> getDepartments(String divuuid) {
    final div = divs[divuuid];
    if (div != null) {
      final departments = Map.fromEntries(div.departments.map((uuid) => MapEntry(uuid, deps[uuid])));
      return sortMapValues<String, Department, String>(
        departments ?? {},
        (department) => department.name,
      ).values;
    }
    return [];
  }

  /// Search for affiliations matching given [filter]
  /// from [repo.service] and store matches in [repo]
  Future<List<Affiliation>> search(
    String filter, {
    int offset = 0,
    int limit = 20,
  }) async {
    return dispatch(
      SearchAffiliations(
        filter,
        limit: limit,
        offset: offset,
      ),
    );
  }

  /// Fetch given affiliations from [repo]
  Future<List<Affiliation>> fetch(Iterable<String> uuids) async {
    return dispatch(
      FetchAffiliations(uuids: uuids.toList()),
    );
  }

  /// Load affiliations from [repo]
  Future<List<Affiliation>> load() async {
    return dispatch(
      LoadAffiliations(),
    );
  }

  /// Onboard current user. If already onboarded
  /// existing [affiliation] is returned.
  Future<Affiliation> onboard({
    String userId,
    AffiliationType type = AffiliationType.member,
    AffiliationStandbyStatus status = AffiliationStandbyStatus.available,
  }) async {
    _assertState('onboard');
    final affiliation = findUserAffiliation(userId: userId);
    if (!repo.containsKey(affiliation.uuid)) {
      return dispatch(
        OnboardUser(
          userId ?? users.user.userId,
          affiliation.copyWith(
            status: status,
            uuid: Uuid().v4(),
            type: affiliation.isUnorganized ? AffiliationType.volunteer : type,
          ),
        ),
      );
    }
    return affiliation;
  }

  /// Check if [Affiliation.uuid] is [Affiliation.temporary]
  bool isTemporary(String uuid) {
    final affiliation = repo[uuid];
    return affiliation?.isUnorganized == true || persons[affiliation?.person?.uuid].temporary == true;
  }

  /// Create affiliation for temporary
  /// personnel. A temporary [Person] will
  /// only be created from [Personnel] if
  /// given [personnel] have no affiliation
  /// already. Otherwise, existing affiliation
  /// is returned.
  Future<Affiliation> temporary(
    Personnel personnel,
    Affiliation affiliation,
  ) async {
    _assertState('temporary');
    final current = findPersonnelAffiliation(personnel);
    if (!repo.containsKey(current.uuid)) {
      AffiliationUtils.assertRef(personnel);
      return dispatch(
        _assertTemporary(CreateTemporaryAffiliation(
          personnel,
          affiliation,
        )),
      );
    }
    return current;
  }

  Future<Affiliation> update(Affiliation affiliation) {
    _assertState('update');
    return dispatch(
      UpdateAffiliation(affiliation),
    );
  }

  /// Clear all organisations
  Future<List<Affiliation>> unload() {
    return dispatch(UnloadAffiliations());
  }

  @override
  Stream<AffiliationState> execute(AffiliationCommand command) async* {
    if (command is LoadAffiliations) {
      yield* _load(command);
    } else if (command is FetchAffiliations) {
      yield* _fetch(command);
    } else if (command is SearchAffiliations) {
      yield* _search(command);
    } else if (command is OnboardUser) {
      yield* _onboard(command);
    } else if (command is CreateTemporaryAffiliation) {
      yield* _temporary(command);
    } else if (command is UpdateAffiliation) {
      yield* _update(command);
    } else if (command is UnloadAffiliations) {
      yield* _unload(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<AffiliationState> _load(LoadAffiliations command) async* {
    await orgs.load();
    await divs.load();
    await deps.load();

    // Load from local storage
    await repo.init();

    final exists = await _fetchPersons(
      repo.values.where((e) => e.person?.uuid != null).map((e) => e.person.uuid),
    );

    final loaded = toOK(
      command,
      AffiliationsLoaded(
        orgs: orgs.keys,
        divs: orgs.keys,
        deps: orgs.keys,
        persons: exists,
        affiliations: repo.keys,
      ),
      result: repo.values,
    );
    yield loaded;
  }

  Stream<AffiliationState> _fetch(FetchAffiliations command) async* {
    // Load from backend
    await repo.fetch(command.data);

    // Get persons that should exist
    final expected = command.data.where((uuid) => repo.containsKey(uuid)).map(
          (uuid) => repo[uuid].person.uuid,
        );

    final exists = await _fetchPersons(expected);

    final loaded = toOK(
      command,
      AffiliationsFetched(
        affiliations: repo.keys,
        persons: exists,
      ),
      result: repo.values,
    );
    yield loaded;
  }

  Stream<AffiliationState> _search(SearchAffiliations command) async* {
    // Load from backend
    final affiliations = await repo.search(
      command.data,
      limit: command.limit,
      offset: command.offset,
    );

    final exists = await _fetchPersons(
      affiliations.map((a) => a.person.uuid),
    );

    final loaded = toOK(
      command,
      AffiliationsFetched(
        affiliations: repo.keys,
        persons: exists,
      ),
      result: repo.values,
    );
    yield loaded;
  }

  Future<Iterable<String>> _fetchPersons(Iterable<String> puuids) async {
    try {
      await persons.fetch(
        uuids: puuids,
      );
    } on PersonServiceException catch (e) {
      if (!(e.response.is404 || e.response.is406)) {
        rethrow;
      }
      // Remove affiliations with persons not found
      repo.values
          .where((affiliation) => !persons.containsKey(affiliation.person.uuid))
          .forEach((affiliation) => repo.delete(affiliation.uuid));
    }
    return puuids.where((puuid) => persons.containsKey(puuid));
  }

  Stream<AffiliationState> _onboard(OnboardUser command) async* {
    _assertOnboarding(command);
    var person = persons.findUser(command.data);
    if (person == null) {
      person = await persons.create(PersonModel.fromUser(
        users.repo[command.data],
        temporary: command.affiliation.isUnorganized,
      ));
    }
    final affiliation = await repo.create(command.affiliation.copyWith(
      person: AggregateRef.fromType<PersonModel>(person.uuid),
    ));

    final loaded = toOK(
      command,
      UserOnboarded(
        person: person,
        userId: command.data,
        affiliation: affiliation,
      ),
      result: affiliation,
    );
    yield loaded;
  }

  Stream<AffiliationState> _temporary(CreateTemporaryAffiliation command) async* {
    _assertTemporary(command);
    var person = persons.findUser(command.data.userId);
    if (person == null) {
      person = await persons.create(PersonModel.fromPersonnel(
        command.data,
        temporary: true,
      ));
    }
    final affiliation = await repo.create(command.affiliation.copyWith(
      person: person.toRef(),
      type: command.affiliation.type ?? AffiliationType.volunteer,
      status: command.affiliation.status ?? AffiliationStandbyStatus.available,
    ));
    final loaded = toOK(
      command,
      PersonnelAffiliated(
        personnel: command.data,
        affiliation: affiliation,
      ),
      result: affiliation,
    );
    yield loaded;
  }

  Stream<AffiliationState> _update(UpdateAffiliation command) async* {
    final affiliation = await repo.update(command.data);
    final updated = toOK(
      command,
      AffiliationUpdated(affiliation),
      result: affiliation,
    );
    yield updated;
  }

  Stream<AffiliationState> _unload(UnloadAffiliations command) async* {
    // Execute commands
    final _deps = await deps.close();
    final _divs = await divs.close();
    final _orgs = await orgs.close();
    final _persons = await persons.close();
    final _affiliations = await repo.close();

    final unloaded = toOK(
      command,
      AffiliationsUnloaded(
        orgs: _orgs.map((e) => e.uuid),
        divs: _divs.map((e) => e.uuid),
        deps: _deps.map((e) => e.uuid),
        persons: _persons.map((e) => e.uuid),
        affiliations: _affiliations.map((e) => e.uuid),
      ),
      result: _affiliations,
    );
    yield unloaded;
  }

  @override
  Future<void> close() async {
    super.close();
    await deps.dispose();
    await divs.dispose();
    await orgs.dispose();
    await persons.dispose();
    return repo.dispose();
  }

  @override
  AffiliationBlocError createError(Object error, {StackTrace stackTrace}) => AffiliationBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  void _assertOnboarding(OnboardUser command) {
    final current = findUserAffiliation(userId: command.data);
    if (repo.containsKey(current.uuid)) {
      throw ArgumentError("User ${command.data} already onboarded");
    } else if (command.affiliation.uuid == null) {
      throw ArgumentError("Affiliation has no uuid");
    }
  }

  CreateTemporaryAffiliation _assertTemporary(CreateTemporaryAffiliation command) {
    if (command.affiliation.uuid == null) {
      throw ArgumentError("Temporary affiliation has no uuid");
    } else if (command.data.affiliation?.uuid != command.affiliation.uuid) {
      throw ArgumentError("Temporary affiliation uuids does not match");
    }
    AffiliationUtils.assertRef(command.data);
    return command;
  }

  void _assertState(String action) {
    if (!repo.isReady) {
      throw AffiliationBlocError(
        "Bloc not ready. "
        "Ensure 'AffiliationBloc.load()' before '$action'",
      );
    }
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class AffiliationCommand<S, T> extends BlocCommand<S, T> {
  AffiliationCommand(
    S data, {
    props = const [],
  }) : super(data, props);
}

class LoadAffiliations extends AffiliationCommand<void, List<Affiliation>> {
  LoadAffiliations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class FetchAffiliations extends AffiliationCommand<List<String>, List<Affiliation>> {
  FetchAffiliations({List<String> uuids = const []}) : super(uuids);

  @override
  String toString() => '$runtimeType {uuids: $data}';
}

class SearchAffiliations extends AffiliationCommand<String, List<Affiliation>> {
  SearchAffiliations(
    String filter, {
    this.offset = 0,
    this.limit = 20,
  }) : super(filter);

  final int limit;
  final int offset;

  @override
  String toString() => '$runtimeType {filter: $data, limit: $limit, offset: $offset}';
}

class OnboardUser extends AffiliationCommand<String, Affiliation> {
  final Affiliation affiliation;
  OnboardUser(String userId, this.affiliation) : super(userId, props: [affiliation]);

  @override
  String toString() => '$runtimeType {userId: $data, affiliation: $affiliation}';
}

class CreateTemporaryAffiliation extends AffiliationCommand<Personnel, Affiliation> {
  final Affiliation affiliation;
  CreateTemporaryAffiliation(Personnel personnel, this.affiliation)
      : super(
          personnel,
          props: [affiliation],
        );

  @override
  String toString() => '$runtimeType {personnel: $data, affiliation: $affiliation}';
}

class UpdateAffiliation extends AffiliationCommand<Affiliation, Affiliation> {
  UpdateAffiliation(Affiliation affiliation) : super(affiliation);

  @override
  String toString() => '$runtimeType {affiliation: $data}';
}

class UnloadAffiliations extends AffiliationCommand<void, List<Affiliation>> {
  UnloadAffiliations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class AffiliationState<T> extends BlocEvent<T> {
  AffiliationState(
    T data, {
    props = const [],
    StackTrace stackTrace,
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isEmpty() => this is AffiliationsEmpty;
  bool isLoaded() => this is AffiliationsLoaded;
  bool isUnloaded() => this is AffiliationsUnloaded;
  bool isError() => this is AffiliationBlocError;
}

class AffiliationsEmpty extends AffiliationState<void> {
  AffiliationsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class AffiliationsLoaded extends AffiliationState<Iterable<String>> {
  AffiliationsLoaded({
    this.orgs,
    this.deps,
    this.divs,
    this.persons,
    Iterable<String> affiliations,
  }) : super(affiliations);

  final Iterable<String> orgs;
  final Iterable<String> deps;
  final Iterable<String> divs;
  final Iterable<String> persons;

  @override
  String toString() => '$runtimeType {'
      'orgs: $orgs, '
      'divs: $divs, '
      'deps: $deps, '
      'persons: $persons, '
      'affiliations: $data'
      '}';
}

class AffiliationsFetched extends AffiliationState<Iterable<String>> {
  AffiliationsFetched({
    this.persons,
    Iterable<String> affiliations,
  }) : super(affiliations);

  final Iterable<String> persons;

  @override
  String toString() => '$runtimeType {'
      'persons: $persons, '
      'affiliations: $data'
      '}';
}

class UserOnboarded extends AffiliationState<Affiliation> {
  UserOnboarded({
    this.userId,
    this.person,
    Affiliation affiliation,
  }) : super(affiliation);

  final String userId;
  final Person person;

  @override
  String toString() => '$runtimeType {'
      'userId: $userId, '
      'person: $person, '
      'affiliation: $data'
      '}';
}

class PersonnelAffiliated extends AffiliationState<Affiliation> {
  PersonnelAffiliated({
    this.personnel,
    Affiliation affiliation,
  }) : super(affiliation);

  final Personnel personnel;

  @override
  String toString() => '$runtimeType {'
      'personnel: $personnel, '
      'affiliation: $data'
      '}';
}

class AffiliationUpdated extends AffiliationState<Affiliation> {
  AffiliationUpdated(Affiliation affiliation) : super(affiliation);

  @override
  String toString() => '$runtimeType {affiliation: $data}';
}

class AffiliationsUnloaded extends AffiliationState<Iterable<String>> {
  AffiliationsUnloaded({
    this.orgs,
    this.deps,
    this.divs,
    this.persons,
    Iterable<String> affiliations,
  }) : super(affiliations);

  final Iterable<String> orgs;
  final Iterable<String> deps;
  final Iterable<String> divs;
  final Iterable<String> persons;

  @override
  String toString() => '$runtimeType {'
      'orgs: $orgs, '
      'divs: $divs, '
      'deps: $deps, '
      'persons: $persons, '
      'affiliations: $data'
      '}';
}

/// ---------------------
/// Error States
/// ---------------------
class AffiliationBlocError extends AffiliationState<Object> {
  AffiliationBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class AffiliationBlocException implements Exception {
  AffiliationBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final AffiliationState state;
  final StackTrace stackTrace;
  final AffiliationCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}

/// --------------------------------------------
/// Helper class for querying for [Affiliation]s
/// --------------------------------------------
///
class AffiliationQuery {
  final AffiliationBloc bloc;
  final Map<String, Aggregate> _aggregates;

  AffiliationQuery(
    /// [AffiliationBloc] managing affiliations
    this.bloc, {

    /// Aggregates included in query
    Map<String, Aggregate> aggregates,
  }) : _aggregates = aggregates ?? toAggregates(bloc);

  static Map<String, Aggregate> toAggregates<String, Aggregate>(
    AffiliationBloc bloc, {
    bool Function(Aggregate aggregate) where,
  }) =>
      Map<String, Aggregate>.from(bloc.orgs.map)
        ..addAll(bloc.divs.map.cast())
        ..addAll(bloc.deps.map.cast())
        ..addAll(bloc.repo.map.cast())
        ..addAll(bloc.persons.map.cast())
        ..removeWhere((_, aggregate) => !(where == null || where(aggregate)));

  /// Get all divisions regardless of organisation
  Iterable<Organisation> get organisations => _aggregates.values.whereType<OrganisationModel>();

  /// Get all divisions regardless of organisation
  Iterable<Division> get divisions => _aggregates.values.whereType<DivisionModel>();

  /// Get all departments regardless of organisation
  Iterable<Department> get departments => _aggregates.values.whereType<DepartmentModel>();

  /// Get all organisational entities
  Iterable<Affiliation> get entities => find(types: [OrganisationModel, DivisionModel, DepartmentModel]);

  /// Get all affiliated persons as [Affiliations]s
  Iterable<Affiliation> get affiliates => _aggregates.values.whereType<AffiliationModel>().where(
        (test) => test.isAffiliate,
      );

  /// Get all [person]s with an affiliation
  Iterable<Person> get persons => affiliates.where((a) => _aggregates.containsKey(a.person?.uuid)).map(
        (a) => _aggregates[a.person.uuid],
      );

  /// Test if given [uuid] is contained in any [Affiliation] in this [AffiliationQuery]
  bool contains(String uuid) => _aggregates.containsKey(uuid);

  /// Get [Affiliation] with child [Aggregate.uuid] as leaf
  ///
  /// It is guaranteed that only one affiliation contains
  /// any given child as leaf.
  ///
  Affiliation elementAt(String uuid) {
    if (!contains(uuid)) {
      return null;
    }
    final child = _aggregates[uuid];
    switch (child.runtimeType) {
      case OrganisationModel:
        return AffiliationModel(
          org: AggregateRef.fromType<OrganisationModel>(uuid),
        );
      case DivisionModel:
        return AffiliationModel(
          org: AggregateRef.fromType<OrganisationModel>((child as Division).organisation.uuid),
          div: AggregateRef.fromType<DivisionModel>(uuid),
        );
      case DepartmentModel:
        return AffiliationModel(
          org: AggregateRef.fromType<OrganisationModel>(
            (_aggregates[(child as Department).division.uuid] as Division).organisation.uuid,
          ),
          div: AggregateRef.fromType<DivisionModel>((child as Department).division.uuid),
          dep: AggregateRef.fromType<DepartmentModel>(uuid),
        );
      case PersonModel:
        return _aggregates.values.whereType<Affiliation>().firstWhere(
              (element) => element.person.uuid == child.uuid,
              orElse: () => null,
            );
      case AffiliationModel:
        return child;
    }
    throw UnimplementedError(
      "Unexpected affiliation type: ${child.runtimeType}",
    );
  }

  /// Find all [Affiliation] of type [T]
  /// at any position in the affiliation tree
  ///
  Iterable<Affiliation> find<T extends Aggregate>({
    String uuid,
    List<Type> types,
    bool Function(Aggregate aggregate) where,
  }) {
    switch (_toModelType(T)) {
      // Search for parent types
      case OrganisationModel:
        if (uuid == null) {
          return _findTyped<OrganisationModel>(where);
        }
        // Get affiliations for all divisions
        // and departments in organisation
        if (_accept<T>(uuid, where)) {
          final child = (_aggregates[uuid] as Organisation);
          final divisions = _findChildren<Division>(child.divisions, where);
          return [
            elementAt(uuid),
            ...divisions.map((div) => elementAt(div.uuid)),
            ...divisions.fold(
                <Affiliation>[],
                (found, div) => _findLeafs<Department>(
                      div.departments,
                      where,
                    ))
          ];
        }
        return [];
      case DivisionModel:
        if (uuid == null) {
          return _findTyped<DivisionModel>(where);
        }
        // Get affiliations for all
        // departments in division
        if (_accept<T>(uuid, where)) {
          final child = (_aggregates[uuid] as Division);
          final departments = _findLeafs<Department>(child.departments, where);
          return [
            elementAt(uuid),
            ...departments,
          ];
        }
        return [];
      // Search for leaf types
      case DepartmentModel:
        return uuid == null
            ? // Match against all instances of given type
            _findTyped<DepartmentModel>(where)
            : // Match against given uuid
            _accept<DepartmentModel>(uuid, where) ? [elementAt(uuid)] : [];
      case AffiliationModel:
        return uuid == null
            ? // Match against all instances of given type
            _findTyped<AffiliationModel>(where)
            : // Match against given uuid
            _accept<AffiliationModel>(uuid, where) ? [elementAt(uuid)] : [];
      case PersonModel:
        return uuid == null
            ? // Match against all instances of given type
            _findTyped<PersonModel>(where)
            : // Match against given uuid
            _accept<PersonModel>(uuid, where) ? [elementAt(uuid)] : [];
      default:
        return uuid == null
            ? // Match against all instances of given type(s)
            types?.isNotEmpty == true ? _findTypes(_toModelTypes(types), where) : _findAny(where)
            : // Match against given uuid
            _accept<T>(uuid, where, types: _toModelTypes(types)) ? [elementAt(uuid)] : [];
    }
  }

  Iterable<T> _findChildren<T extends Aggregate>(List<String> uuids, bool where(Aggregate aggregate)) => uuids
      .map((uuid) => _aggregates[uuid] as T)
      .where((aggregate) => aggregate != null && (where == null || where(aggregate)));

  Iterable<Affiliation> _findLeafs<T extends Aggregate>(
    List<String> uuids,
    bool where(Aggregate aggregate), {
    List<Type> types = const [],
  }) =>
      uuids
          .where((uuid) => _aggregates.containsKey(uuid))
          .map((uuid) => _aggregates[uuid])
          .where((aggregate) => aggregate is T || isType(aggregate, types))
          .where((aggregate) => where == null || where(aggregate))
          .map((aggregate) => elementAt(aggregate.uuid));

  List<Type> _toModelTypes(List<Type> types) => (types ?? []).map(_toModelType).toList();

  Type _toModelType(Type type) {
    switch (type) {
      case Organisation:
      case OrganisationModel:
        return OrganisationModel;
      case Division:
      case DivisionModel:
        return DivisionModel;
      case Department:
      case DepartmentModel:
        return DepartmentModel;
      case Affiliation:
      case AffiliationModel:
        return AffiliationModel;
      case Person:
      case PersonModel:
        return PersonModel;
      case Aggregate:
        return type;
      default:
        throw ArgumentError('Type $type is not supported');
    }
  }

  bool isType(Aggregate aggregate, List<Type> types) => types.contains(aggregate.runtimeType);

  Iterable<Affiliation> _findAny(
    bool where(Aggregate aggregate),
  ) =>
      _aggregates.values.where((aggregate) => where == null || where(aggregate)).fold(
        <Affiliation>[],
        (found, next) {
          switch (next.runtimeType) {
            case OrganisationModel:
            case DivisionModel:
            case DepartmentModel:
            case AffiliationModel:
            case PersonModel:
              return List.from(found)
                ..add(elementAt(
                  next.uuid,
                ));
            default:
              throw UnimplementedError(
                "Unexpected affiliation type ${next.runtimeType}",
              );
          }
        },
      );

  Iterable<Affiliation> _findTyped<T extends Aggregate>(
    bool where(Aggregate aggregate),
  ) =>
      _aggregates.values.whereType<T>().fold(
        <Affiliation>[],
        (found, next) => List.from(found)
          ..addAll(find<T>(
            uuid: next.uuid,
            where: where,
          )),
      );

  Iterable<Affiliation> _findTypes(
    List<Type> types,
    bool where(Aggregate aggregate),
  ) =>
      _aggregates.values.where((aggregate) => isType(aggregate, types)).fold(
        <Affiliation>[],
        (found, next) => List.from(found)
          ..addAll(find(
            uuid: next.uuid,
            where: where,
            types: types,
          )),
      );

  bool _accept<T>(
    String uuid,
    bool where(Aggregate aggregate), {
    List<Type> types = const [],
  }) {
    final aggregate = _aggregates[uuid];
    if (aggregate != null) {
      final type = aggregate.runtimeType;
      return (typeOf<T>() == type || types.contains(type)) && (where == null || where(_aggregates[uuid]));
    }
    return false;
  }

  /// Get filtered map of [Affiliation.uuid] to [Device] or
  /// [Affiliation] tracked by aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  AffiliationQuery where({
    String uuid,
    bool Function(Aggregate aggregate) where,
  }) =>
      AffiliationQuery(
        bloc,
        aggregates: Map.from(_aggregates)
          ..removeWhere(
            (_, aggregate) => !(where == null || where(aggregate)),
          ),
      );
}
