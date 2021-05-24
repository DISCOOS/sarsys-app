import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
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
import 'package:SarSys/core/utils/data.dart';

import 'affiliation_commands.dart';
import 'affiliation_query.dart';
import 'affiliation_states.dart';

export 'affiliation_commands.dart';
export 'affiliation_query.dart';
export 'affiliation_states.dart';

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
/// supported by 'GET /api/affiliations'.
///
/// New users are onboarded based on claims in
/// access-tokens. Users without any
/// affiliation with an organisations are
/// onboarded as temporary Persons. If the same
/// physical person signs in with multiple
/// accounts, an new Person will be onboarded
/// for each account, leading to Person duplicates
///
class AffiliationBloc extends StatefulBloc<AffiliationCommand, AffiliationState, AffiliationBlocError, String,
    Affiliation, AffiliationService> with LoadableBloc<List<Affiliation>>, UnloadableBloc<List<Affiliation>> {
  ///
  /// Default constructor
  ///
  AffiliationBloc({
    @required this.users,
    @required this.repo,
    @required BlocEventBus bus,
  }) : super(AffiliationsEmpty(), bus: bus) {
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

    registerStreamSubscription(users.stream.listen(
      // Load and unload repos as needed
      _processUserState,
    ));

    // Notify when repository states change
    forward<Person>(
      (t) => _NotifyRepositoryStateChanged<Person>(t),
    );
    forward<Affiliation>(
      (t) => _NotifyRepositoryStateChanged<Affiliation>(t),
    );
    forward<Organisation>(
      (t) => _NotifyRepositoryStateChanged<Organisation>(t),
    );
    forward<Division>(
      (t) => _NotifyRepositoryStateChanged<Division>(t),
    );
    forward<Department>(
      (t) => _NotifyRepositoryStateChanged<Department>(t),
    );
  }

  /// All repositories
  Iterable<StatefulRepository> get repos => [
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

  /// Get all [Affiliation]s
  Iterable<Affiliation> get values => repo.values;

  /// Get [Affiliation] from [uuid]
  Affiliation operator [](String uuid) => repo[uuid];

  /// Get [AffiliationRepository]
  final AffiliationRepository repo;

  /// Get [UserBloc]
  final UserBloc users;

  void _processUserState(UserState state) async {
    try {
      if (isOpen) {
        if (state.shouldLoad() && repo.isNotReady) {
          // Wait for load before onboarding user
          await dispatch(LoadAffiliations());
          await onboardUser();
        } else if (state.shouldUnload(isOnline: isOnline) && repo.isReady) {
          dispatch(UnloadAffiliations());
        }
      }
    } catch (error, stackTrace) {
      addError(
        error,
        stackTrace,
      );
      onError(error, stackTrace);
    }
  }

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

  /// Get searchable string from [Affiliation.uuid]
  String toSearchable(String uuid) {
    final affiliation = repo[uuid];
    if (affiliation?.person?.uuid != null) {
      final person = persons[affiliation.person.uuid];
      return "${person?.searchable} ${affiliation?.searchable}";
    }
    return "${affiliation?.searchable ?? ''}";
  }

  /// Find [Affiliation]s matching given query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)}) => repo.find(where: where);

  /// Find [Affiliation]s matching given  query
  Iterable<Affiliation> findAffiliates(Person person) => repo.findPerson(person.uuid);

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
    bool reverse = false,
  }) {
    final names = [
      orgs[affiliation?.org?.uuid]?.name,
      divs[affiliation?.div?.uuid]?.name,
      deps[affiliation?.dep?.uuid]?.name,
    ]..removeWhere((name) => name == null);
    return names.isEmpty
        ? empty
        : short
            ? names.last
            : (reverse ? names : names.reversed).join(', ');
  }

  /// Get [Person] from given [userId].
  /// If [userId] is not given, current
  /// authenticated user is returned,
  /// or [null] if ont found
  Person findUserPerson({String userId}) =>
      users.isAuthenticated ? persons.findUser(userId ?? users.user.userId) : null;

  /// Get Affiliation from User
  Affiliation findUserAffiliation({
    String userId,
    bool ensure = true,
    AffiliationType defaultType = AffiliationType.volunteer,
    AffiliationStandbyStatus defaultStatus = AffiliationStandbyStatus.available,
  }) {
    // Prepare
    final _userId = userId ?? users.userId;
    final person = findUserPerson(userId: _userId);
    final org = findUserOrganisation(userId: _userId);
    final div = findUserDivision(userId: _userId, org: org);
    final dep = findUserDepartment(userId: _userId, div: div);
    final isUserAffiliated = org != null || div != null || dep != null;

    if (person != null) {
      final affiliations = repo.findPerson(person.uuid);
      // Try to match active affiliation
      final candidates = affiliations.length == 1
          ? [Pair<Affiliation, int>.of(affiliations.first, 0)]
          : affiliations.fold(
              <Pair<Affiliation, int>>[],
              (candidates, a) {
                var rank = 0;
                if (a.org?.uuid != null) {
                  rank++;
                }
                if (a.div?.uuid != null) {
                  rank++;
                }
                if (a.dep?.uuid != null) {
                  rank++;
                }
                return candidates
                  ..add(
                    Pair<Affiliation, int>.of(a, rank),
                  );
              },
            );
      if (candidates.isNotEmpty) {
        // Choose affiliation with highest rank
        final sorted = sortList<Pair<Affiliation, int>>(
          candidates,
          (a, b) => b.right - a.right,
        );

        final affiliation = sorted.first.left;

        // Only reuse if user has an existing affiliation
        // with an organisation or user is not affiliated with
        // any known organisation. Otherwise, create a new
        // affiliation
        if (affiliation.isOrganized || !isUserAffiliated) {
          return affiliation;
        }
      }
    }

    // Create new affiliation
    final isUnorganized = org == null && div == null && dep == null;
    final affiliation = AffiliationModel(
      uuid: Uuid().v4(),
      type: defaultType,
      org: org?.toRef(),
      div: div?.toRef(),
      dep: dep?.toRef(),
      status: defaultStatus,
      person: person ??
          PersonModel.fromUser(
            users.repo[_userId],
            temporary: isUnorganized,
          ),
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
  }) {
    final affiliation = repo[personnel?.affiliation?.uuid];
    if (affiliation == null) {
      return findUserAffiliation(
        ensure: ensure,
        userId: personnel.userId,
        defaultType: defaultType,
        defaultStatus: defaultStatus,
      )?.copyWith(
        uuid: AffiliationUtils.assertRef(personnel),
      );
    }
    return affiliation;
  }

  /// Get [Organisation] from [userId]
  Organisation findUserOrganisation({String userId}) {
    List<Affiliation> affiliates;
    var user = users.repo[userId];
    if (user == null) {
      final person = persons.findUser(userId);
      if (person != null) {
        affiliates = findAffiliates(person).toList();
        final ouuids = affiliates
            .where(
              (a) => a.org?.uuid != null,
            )
            .map((a) => a.org.uuid)
            .toList();
        if (ouuids.isNotEmpty) {
          return orgs[ouuids.first];
        }
      }
      user = users.repo.user;
    }
    if (user != null) {
      final name = user.org?.toLowerCase();
      final found = orgs.values
          .where(
            (org) => org.name.toLowerCase() == name,
          )
          ?.firstOrNull;
      if (found != null) {
        return found;
      }
    }
    final div = findUserDivision(
      userId: userId,
      affiliates: affiliates,
    );
    if (div != null) {
      return orgs[div.organisation?.uuid];
    }
    final dep = findUserDepartment(
      userId: userId,
      affiliates: affiliates,
    );
    if (dep != null) {
      return orgs[divs[dep.division?.uuid]?.organisation?.uuid];
    }
    return null;
  }

  /// Get Division from User
  Division findUserDivision({
    String userId,
    Organisation org,
    List<Affiliation> affiliates,
  }) {
    var user = users.repo[userId];
    if (user == null) {
      final person = persons.findUser(userId);
      if (person != null) {
        affiliates = affiliates ?? findAffiliates(person).toList();
        final duuids = affiliates
            .where(
              (a) => a.div?.uuid != null && (org == null || org.uuid == a.org?.uuid),
            )
            .map((a) => a.div.uuid);
        if (duuids.isNotEmpty) {
          return divs[duuids.first];
        }
      }
      user = users.repo.user;
    }
    if (user != null) {
      final name = user.div?.toLowerCase();
      final duuids = org?.divisions ?? <String>[];
      return divs.values
          .where((division) => duuids.isEmpty || duuids.contains(division.uuid))
          .where((division) => division.name.toLowerCase() == name)
          ?.firstOrNull;
    }
    final dep = findUserDepartment(
      userId: userId,
      affiliates: affiliates,
    );
    if (dep != null) {
      return divs[dep.division?.uuid];
    }
    return null;
  }

  /// Get Department id from User
  Department findUserDepartment({
    String userId,
    Division div,
    List<Affiliation> affiliates,
  }) {
    var user = users.repo[userId];
    if (user == null) {
      final person = persons.findUser(userId);
      if (person != null) {
        affiliates = affiliates ?? findAffiliates(person).toList();
        final duuids = affiliates
            .where(
              (a) => a.dep?.uuid != null && (div == null || div.uuid == a.div?.uuid),
            )
            .map((a) => a.dep.uuid);
        if (duuids.isNotEmpty) {
          return deps[duuids.first];
        }
      }
      user = users.repo.user;
    }
    if (user != null) {
      final name = (user ?? users.user).dep?.toLowerCase();
      final duuids = div?.departments ?? <String>[];
      return deps.values
          .where((department) => duuids.isEmpty || duuids.contains(department.uuid))
          .where((department) => department.name.toLowerCase() == name)
          ?.firstOrNull;
    }
    return null;
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
    return org == null ? null : AffiliationUtils.findFunction(org.fleetMap, number);
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

  /// Get all [Organisation] sorted on [Organisation.name]
  Iterable<Organisation> getOrganisations() {
    return sortMapValues<String, Organisation, String>(
      orgs.map ?? <String, Organisation>{},
      (org) => org.name,
    ).values;
  }

  /// Get divisions in given [Organisation] sorted on [Division.name]
  Iterable<Division> getDivisions(String orguuid) {
    final org = orgs[orguuid];
    if (org?.divisions?.isNotEmpty == true) {
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
    if (div?.departments?.isNotEmpty == true) {
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
  Future<Affiliation> onboardUser({
    String userId,
    AffiliationType type = AffiliationType.member,
    AffiliationStandbyStatus status = AffiliationStandbyStatus.available,
  }) async {
    await _assertState('onboard');
    await onLoadedAsync();
    final _userId = userId ?? users.user.userId;
    final affiliation = findUserAffiliation(userId: _userId);
    if (!repo.containsKey(affiliation.uuid)) {
      return dispatch(
        OnboardUser(
          _userId,
          affiliation.copyWith(
            status: status,
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
    return affiliation?.isUnorganized == true;
  }

  /// Create affiliation for temporary
  /// personnel. A temporary [Person] will
  /// only be created from [Personnel] if
  /// given [personnel] have no affiliation
  /// already. Otherwise, existing affiliation
  /// is returned.
  Future<Affiliation> create(
    Affiliation affiliation,
  ) async {
    await _assertState('create');
    if (!repo.containsKey(affiliation.uuid)) {
      return dispatch(
        _assertData(CreateAffiliation(
          affiliation,
        )),
      );
    }
    return repo[affiliation.uuid];
  }

  Future<Affiliation> update(Affiliation affiliation) async {
    await _assertState('update');
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
    } else if (command is CreateAffiliation) {
      yield* _create(command);
    } else if (command is UpdateAffiliation) {
      yield* _update(command);
    } else if (command is UnloadAffiliations) {
      yield* _unload(command);
    } else if (command is _NotifyRepositoryStateChanged) {
      yield _notify(command);
    } else if (command is _NotifyBlocStateChanged) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<AffiliationState> _load(LoadAffiliations command) async* {
    // Read local values
    await persons.init();

    final onOrgs = Completer<Iterable<Organisation>>();
    await orgs.load(onRemote: onOrgs);

    final onDivs = Completer<Iterable<Division>>();
    await divs.load(onRemote: onDivs);

    final onDeps = Completer<Iterable<Department>>();
    await deps.load(onRemote: onDeps);

    final onAffiliations = Completer<Iterable<Affiliation>>();
    final cached = await repo.load(
      onRemote: onAffiliations,
    );

    yield toOK(
      command,
      AffiliationsLoaded(
        orgs: orgs.keys,
        divs: divs.keys,
        deps: deps.keys,
        isRemote: false,
        affiliations: repo.keys,
        persons: repo.persons.keys,
      ),
      result: cached,
    );

    // Notify when orgs, divs, deps
    // and affiliations are fetched
    // from remote storage
    onComplete(
      [
        onOrgs.future,
        onDivs.future,
        onDeps.future,
        onAffiliations.future,
      ],
      toState: (_) => AffiliationsLoaded(
        orgs: orgs.keys,
        divs: divs.keys,
        deps: deps.keys,
        isRemote: true,
        affiliations: repo.keys,
        persons: repo.persons.keys,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Iterable<String>>(state),
      toError: (Object error, StackTrace stackTrace) {
        if (!onFetchPersonsError(error)) {
          // Do not call sink.addError
          // since toOK has already
          // invoked command.callback
          return toError(
            command,
            error,
            stackTrace: stackTrace,
          );
        }
        return null;
      },
    );
  }

  Stream<AffiliationState> _fetch(FetchAffiliations command) async* {
    final uuids = command.data;
    final onRemote = Completer<Iterable<Affiliation>>();
    final cached = await repo.fetch(
      uuids,
      onRemote: onRemote,
    );

    yield toOK(
      command,
      AffiliationsFetched(
        isRemote: false,
        affiliations: command.data,
        persons: cached.map((e) => e.person?.uuid).whereNotNull().toList(),
      ),
      result: cached,
    );

    // Notify when affiliations are fetched from remote storage
    onComplete<Iterable<Affiliation>>(
      [onRemote.future],
      toState: (results) {
        return AffiliationsFetched(
          isRemote: true,
          affiliations: results.firstOrNull?.map((a) => a.uuid) ?? <String>[],
          persons: results.whereType<Affiliation>().map((e) => e.person?.uuid).whereNotNull().toList(),
        );
      },
      toCommand: (state) => _NotifyBlocStateChanged<Iterable<String>>(state),
      toError: (Object error, StackTrace stackTrace) {
        if (!onFetchPersonsError(error)) {
          // Do not call sink.addError
          // since toOK has already
          // invoked command.callback
          return toError(
            command,
            error,
            stackTrace: stackTrace,
          );
        }
        return null;
      },
    );
  }

  Stream<AffiliationState> _search(SearchAffiliations command) async* {
    // Search for affiliations in backend
    final affiliations = await repo.search(
      command.data,
      limit: command.limit,
      offset: command.offset,
    );

    yield toOK(
      command,
      AffiliationsFetched(
        isRemote: true,
        affiliations: affiliations.map((a) => a.uuid),
        persons: affiliations.map((e) => e.person?.uuid).whereNotNull().toList(),
      ),
      result: affiliations,
    );
  }

  bool onFetchPersonsError(Object error) {
    // Remove affiliations with persons not found
    final shouldRemove = error is ServiceResponse && (error.is404 || error.is206);
    if (shouldRemove) {
      _removeMissingPersons();
    }
    return shouldRemove;
  }

  void _removeMissingPersons() => repo.values
      .where((affiliation) => !persons.containsKey(affiliation.person?.uuid))
      .forEach((affiliation) => repo.delete(affiliation.uuid));

  Stream<AffiliationState> _onboard(OnboardUser command) async* {
    _assertOnboarding(command);
    final userId = command.data;
    var affiliation = command.affiliation;

    // Find user
    final person = _ensurePerson(userId, affiliation);

    // Ensure person is applied to affiliation
    affiliation = repo.apply(affiliation.copyWith(
      person: person,
    ));

    final created = toOK(
      command,
      UserOnboarded(
        person: person,
        userId: userId,
        affiliation: affiliation,
      ),
      result: affiliation,
    );
    yield created;

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(affiliation.uuid)],
      toState: (_) => UserOnboarded(
        isRemote: true,
        person: person,
        userId: command.data,
        affiliation: affiliation,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Affiliation>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Person _ensurePerson(String userId, Affiliation affiliation) {
    return persons.findUser(userId) ??
        affiliation.person ??
        PersonModel.fromUser(
          users.repo[userId],
          temporary: affiliation.isUnorganized,
        );
  }

  Stream<AffiliationState> _create(CreateAffiliation command) async* {
    _assertData(command);
    final person = _ensurePerson(
      command.person.userId,
      command.data,
    );
    final affiliation = repo.apply(command.data.copyWith(
      person: person,
      type: command.data.type ?? AffiliationType.volunteer,
      status: command.data.status ?? AffiliationStandbyStatus.available,
    ));
    final created = toOK(
      command,
      AffiliationCreated(
        affiliation,
      ),
      result: affiliation,
    );
    yield created;

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(affiliation.uuid)],
      toState: (_) => AffiliationCreated(
        affiliation,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged<Affiliation>(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<AffiliationState> _update(UpdateAffiliation command) async* {
    final affiliation = repo.apply(command.data);
    final updated = toOK(
      command,
      AffiliationUpdated(affiliation),
      result: affiliation,
    );
    yield updated;

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(affiliation.uuid)],
      toState: (_) => AffiliationUpdated(
        affiliation,
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

  AffiliationState _notify(_NotifyRepositoryStateChanged command) {
    switch (command.type) {
      case Affiliation:
        return _notifyAffiliationChanged(command);
      case Organisation:
        return _notifyOrganisationChanged(command);
      case Division:
        return _notifyDivisionChanged(command);
      case Department:
        return _notifyDepartmentChanged(command);
      case Person:
        final person = command.state as Person;
        return toOK(
          command,
          AffiliationPersonUpdated(
            person,
            command.previous as Person,
            findAffiliates(person).toList(),
            isRemote: command.isRemote,
          ),
          result: person,
        );
    }
    return toError(
      command,
      'Unknown state status ${command.status}',
      stackTrace: StackTrace.current,
    );
  }

  AffiliationState _notifyAffiliationChanged(_NotifyRepositoryStateChanged command) {
    final state = command.state as Affiliation;
    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          AffiliationCreated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
        break;
      case StorageStatus.updated:
        return toOK(
          command,
          AffiliationUpdated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          AffiliationDeleted(
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

  AffiliationState _notifyOrganisationChanged(_NotifyRepositoryStateChanged command) {
    final state = command.state as Organisation;
    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          OrganisationCreated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.updated:
        return toOK(
          command,
          OrganisationUpdated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          OrganisationDeleted(
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

  AffiliationState _notifyDivisionChanged(_NotifyRepositoryStateChanged command) {
    final state = command.state as Division;

    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          DivisionCreated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.updated:
        return toOK(
          command,
          DivisionUpdated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          DivisionDeleted(
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

  AffiliationState _notifyDepartmentChanged(_NotifyRepositoryStateChanged command) {
    final state = command.state as Department;
    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          DepartmentCreated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.updated:
        return toOK(
          command,
          DepartmentUpdated(
            state,
            isRemote: command.isRemote,
          ),
          result: state,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          DepartmentDeleted(
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
  AffiliationBlocError createError(Object error, {StackTrace stackTrace}) => AffiliationBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  Affiliation _assertOnboarding(OnboardUser command) {
    final current = findUserAffiliation(userId: command.data);
    if (repo.containsKey(current.uuid)) {
      throw ArgumentError("User ${command.data} already onboarded");
    } else if (command.affiliation.uuid == null) {
      throw ArgumentError("Affiliation has no uuid");
    }
    return current;
  }

  CreateAffiliation _assertData(CreateAffiliation command) {
    if (command.data.uuid == null) {
      throw ArgumentError("Temporary affiliation has no uuid");
    }
    return command;
  }

  Future _assertState(String action) {
    if (!repo.isReady) {
      throw AffiliationBlocError(
        "Bloc not ready. "
        "Ensure 'AffiliationBloc.load()' before '$action'",
      );
    }
    return Future.value();
  }
}

/// --------------------------
/// Internal commands
/// --------------------------

class _NotifyRepositoryStateChanged<T> extends AffiliationCommand<StorageTransition<T>, T>
    with NotifyRepositoryStateChangedMixin {
  _NotifyRepositoryStateChanged(StorageTransition<T> transition) : super(transition);
}

class _NotifyBlocStateChanged<T> extends AffiliationCommand<AffiliationState<T>, T>
    with NotifyBlocStateChangedMixin<AffiliationState<T>, T> {
  _NotifyBlocStateChanged(AffiliationState state) : super(state);
}
