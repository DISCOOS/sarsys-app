import 'dart:async';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/OperationalFunction.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/core.dart';

class AffiliationBloc extends BaseBloc<AffiliationCommand, AffiliationState, AffiliationBlocError>
    with LoadableBloc<List<Organisation>>, UnloadableBloc<List<Organisation>>, ConnectionAwareBloc {
  ///
  /// Default constructor
  ///
  AffiliationBloc(
    this.orgs,
    this.divs,
    this.deps,
    this.users,
    BlocEventBus bus,
  ) : super(bus: bus) {
    assert(this.users != null, "userBloc can not be null");
    assert(this.orgs != null, "organisations repository can not be null");
    assert(this.divs != null, "divisions repository can not be null");
    assert(this.deps != null, "departments repository can not be null");
    assert(this.orgs.service != null, "organisations service can not be null");
    assert(this.divs.service != null, "divisions service can not be null");
    assert(this.deps.service != null, "departments service can not be null");

    registerStreamSubscription(users.listen(
      // Load and unload organisations as needed
      _processUserState,
    ));
  }

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [orgs, divs, deps];

  /// Get [OrganisationRepository]
  final OrganisationRepository orgs;

  /// Get [DivisionRepository]
  final DivisionRepository divs;

  /// Get [DepartmentRepository]
  final DepartmentRepository deps;

  /// Get [UserBloc]
  final UserBloc users;

  void _processUserState(UserState state) {
    if (hasSubscriptions) {
      if (state.shouldLoad()) {
        dispatch(LoadAffiliations());
      } else if (state.shouldUnload() && orgs.isReady) {
        dispatch(UnloadAffiliations());
      }
    }
  }

  @override
  AffiliationsEmpty get initialState => AffiliationsEmpty();

  /// Get Affiliation from device number
  Affiliation find(String number) {
    final org = findOrganisation(number);
    final div = findDivision(number);
    final dep = findDepartment(number);
    return Affiliation(
      org: AggregateRef.fromType<Organisation>(org.uuid),
      div: div != null ? AggregateRef.fromType<Division>(div.uuid) : null,
      dep: dep != null ? AggregateRef.fromType<Department>(dep.uuid) : null,
    );
  }

  /// Get full affiliation name as comma-separated list of organisation, division and department names
  String findName(String number, {String empty = 'Ingen'}) {
    final names = [
      findOrganisation(number)?.name,
      findDivision(number)?.name,
      findDepartment(number)?.name,
    ]..removeWhere((name) => name == null);
    return names.isEmpty ? empty : names.join(', ');
  }

  /// Get full affiliation name as comma-separated list of organisation, division and department names
  String toName(Affiliation affiliation, {String empty = 'Ingen'}) {
    final names = [
      orgs[affiliation?.org?.uuid]?.name,
      divs[affiliation?.div?.uuid]?.name,
      deps[affiliation?.dep?.uuid]?.name,
    ]..removeWhere((name) => name == null);
    return names.isEmpty ? empty : names.join(', ');
  }

  /// Get Affiliation from User
  Affiliation findUserAffiliation({User user}) {
    final org = findUserOrganisation(user: user);
    final div = findUserDivision(user: user);
    final dep = findUserDepartment(user: user);
    return Affiliation(
      org: AggregateRef.fromType<Organisation>(org.uuid),
      div: AggregateRef.fromType<Division>(div.uuid),
      dep: AggregateRef.fromType<Department>(dep.uuid),
    );
  }

  /// Get [Organisation] from User
  Organisation findUserOrganisation({User user}) {
    final div = findUserDivision(user: user);
    return orgs[div?.organisation?.uuid];
  }

  /// Get Division from User
  Division findUserDivision({User user}) {
    final name = (user ?? users.user).division?.toLowerCase();
    return divs.values
            .where(
              (division) => division.name.toLowerCase() == name,
            )
            ?.firstOrNull ??
        divs[users.config.divId];
  }

  /// Get Department id from User
  Department findUserDepartment({User user}) {
    final name = (user ?? users.user).department?.toLowerCase();
    return deps.values
            .where(
              (department) => department.name.toLowerCase() == name,
            )
            ?.firstOrNull ??
        deps[users.config.depId];
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
  AffiliationQuery get query => AffiliationQuery(
        this,
        aggregates: AffiliationQuery.toAggregates(this),
      );

  /// Get all [Affiliation]s from current state
  Iterable<Affiliation> get affiliations => query.find();

  /// Fetch organisations from [orgs]
  Future<List<Organisation>> load() async {
    return dispatch(
      LoadAffiliations(),
    );
  }

  /// Clear all organisations
  Future<List<Organisation>> unload() {
    return dispatch(UnloadAffiliations());
  }

  @override
  Stream<AffiliationState> execute(AffiliationCommand command) async* {
    if (command is LoadAffiliations) {
      yield* _load(command);
    } else if (command is UnloadAffiliations) {
      yield* _unload(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<AffiliationState> _load(LoadAffiliations command) async* {
    // Execute commands
    await divs.load();
    await deps.load();
    final organisations = await orgs.load();

    // Complete request
    final loaded = toOK(
      command,
      AffiliationsLoaded(organisations),
      result: organisations,
    );
    yield loaded;
  }

  Stream<AffiliationState> _unload(UnloadAffiliations command) async* {
    // Execute commands
    await divs.close();
    await deps.close();
    List<Organisation> organisations = await orgs.close();
    final unloaded = toOK(
      command,
      AffiliationsUnloaded(organisations),
    );
    yield unloaded;
  }

  @override
  Future<void> close() async {
    await orgs.dispose();
    await orgs.dispose();
    return super.close();
  }

  @override
  AffiliationBlocError createError(Object error, {StackTrace stackTrace}) => AffiliationBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
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

class LoadAffiliations extends AffiliationCommand<void, List<Organisation>> {
  LoadAffiliations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class UnloadAffiliations extends AffiliationCommand<void, List<Organisation>> {
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

class AffiliationsLoaded extends AffiliationState<Iterable<Organisation>> {
  AffiliationsLoaded(Iterable<Organisation> data) : super(data);

  @override
  String toString() => '$runtimeType {organisations: $data}';
}

class AffiliationsUnloaded extends AffiliationState<Iterable<Organisation>> {
  AffiliationsUnloaded(Iterable<Organisation> organisations) : super(organisations);

  @override
  String toString() => '$runtimeType {organisations: $data}';
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

/// -------------------------------------------------
/// Helper class for querying [Affiliation] aggregates
/// -------------------------------------------------
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
        ..removeWhere((_, aggregate) => !(where == null || where(aggregate)));

  /// Get all divisions regardless of organisation
  Iterable<Organisation> get organisations => _aggregates.values.whereType<Organisation>();

  /// Get all divisions regardless of organisation
  Iterable<Division> get divisions => _aggregates.values.whereType<Division>();

  /// Get all departments regardless of organisation
  Iterable<Department> get departments => _aggregates.values.whereType<Department>();

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
        return Affiliation(
          org: AggregateRef.fromType<Organisation>(uuid),
        );
      case DivisionModel:
        return Affiliation(
          org: AggregateRef.fromType<Organisation>((child as Division).organisation.uuid),
          div: AggregateRef.fromType<Division>(uuid),
        );
      case DepartmentModel:
        return Affiliation(
          org: AggregateRef.fromType<Organisation>(
            (_aggregates[(child as Department).division.uuid] as Division).organisation.uuid,
          ),
          div: AggregateRef.fromType<Division>((child as Department).division.uuid),
          dep: AggregateRef.fromType<Department>(uuid),
        );
    }
    throw UnimplementedError(
      "Unexpected affiliation type: ${child.runtimeType}",
    );
  }

  /// Find all [Affiliation] with child [Aggregate]
  /// at any position in the affiliation tree
  ///
  Iterable<Affiliation> find<T extends Aggregate>({
    String uuid,
    bool Function(Aggregate aggregate) where,
  }) {
    switch (T) {
      case OrganisationModel:
        if (uuid == null) {
          return _findTyped<Organisation>(where);
        }
        // Get affiliations for all divisions
        // and departments in organisation
        final child = (_aggregates[uuid] as Organisation);
        final divisions = _findChildren(child.divisions, where);
        return [
          if (_accept(uuid, where)) elementAt(uuid),
          ...divisions.map((div) => elementAt(div.uuid)),
          ...divisions.fold(<Affiliation>[], (found, div) => _findLeafs<Department>(div.departments, where))
        ];
      case DivisionModel:
        if (uuid == null) {
          return _findTyped<Division>(where);
        }
        // Get affiliations for all
        // departments in division
        final child = (_aggregates[uuid] as Division);
        final departments = _findLeafs<Department>(child.departments, where);
        return [
          if (_accept(uuid, where)) elementAt(uuid),
          ...departments,
        ];
      case DepartmentModel:
        return uuid == null
            ? // Match against all departments
            _findTyped<Department>(where)
            : // Department is always a leaf
            _accept(uuid, where) ? [elementAt(uuid)] : [];
      default:
        // Match against all aggregates
        return _findAny(where);
    }
  }

  Iterable<Division> _findChildren(List<String> uuids, bool where(Aggregate aggregate)) {
    return uuids.map((uuid) => _aggregates[uuid] as Division).where((div) => where == null || where(div));
  }

  Iterable<Affiliation> _findLeafs<T extends Aggregate>(
    List<String> uuids,
    bool where(Aggregate aggregate),
  ) =>
      uuids
          .map((uuid) => _aggregates[uuid] as T)
          .where((dep) => where == null || where(dep))
          .map((dep) => elementAt(dep.uuid));

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

  bool _accept(
    String uuid,
    bool where(Aggregate aggregate),
  ) =>
      where == null || where(_aggregates[uuid]);

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
