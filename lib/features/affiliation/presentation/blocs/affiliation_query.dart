import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';

import 'affiliation_bloc.dart';

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
            _accept<DepartmentModel>(uuid, where)
                ? [elementAt(uuid)]
                : [];
      case AffiliationModel:
        return uuid == null
            ? // Match against all instances of given type
            _findTyped<AffiliationModel>(where)
            : // Match against given uuid
            _accept<AffiliationModel>(uuid, where)
                ? [elementAt(uuid)]
                : [];
      case PersonModel:
        return uuid == null
            ? // Match against all instances of given type
            _findTyped<PersonModel>(where)
            : // Match against given uuid
            _accept<PersonModel>(uuid, where)
                ? [elementAt(uuid)]
                : [];
      default:
        return uuid == null
            ? // Match against all instances of given type(s)
            types?.isNotEmpty == true
                ? _findTypes(_toModelTypes(types), where)
                : _findAny(where)
            : // Match against given uuid
            _accept<T>(uuid, where, types: _toModelTypes(types))
                ? [elementAt(uuid)]
                : [];
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
  /// [Affiliation] tracked by aggregate of type [V]
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
