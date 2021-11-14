

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_commands.dart';

/// ---------------------
/// Normal States
/// ---------------------
abstract class AffiliationState<T> extends PushableBlocEvent<T> {
  AffiliationState(
    T data, {
    props = const [],
    StackTrace? stackTrace,
    bool isRemote = false,
  }) : super(
          data,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

  bool isEmpty() => this is AffiliationsEmpty;
  bool isLoaded() => this is AffiliationsLoaded;
  bool isFetched() => this is AffiliationsFetched;
  bool isOnboarded() => this is UserOnboarded;
  bool isAffiliated() => this is AffiliationCreated;
  bool isUnloaded() => this is AffiliationsUnloaded;
  bool isError() => this is AffiliationBlocError;
}

class AffiliationsEmpty extends AffiliationState<void> {
  AffiliationsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class AffiliationsLoaded extends AffiliationState<Iterable<String?>?> {
  AffiliationsLoaded({
    this.orgs,
    this.deps,
    this.divs,
    this.persons,
    bool isRemote = false,
    Iterable<String?>? affiliations,
  }) : super(affiliations, isRemote: isRemote);

  final Iterable<String?>? orgs;
  final Iterable<String?>? deps;
  final Iterable<String?>? divs;
  final Iterable<String?>? persons;

  @override
  String toString() => '$runtimeType {'
      'orgs: $orgs, '
      'divs: $divs, '
      'deps: $deps, '
      'persons: $persons, '
      'isRemote: $isRemote, '
      'affiliations: $data'
      '}';
}

class AffiliationsFetched extends AffiliationState<Iterable<String?>?> {
  AffiliationsFetched({
    this.persons,
    bool isRemote = false,
    Iterable<String?>? affiliations,
  }) : super(affiliations, isRemote: isRemote);

  final Iterable<String>? persons;

  @override
  String toString() => '$runtimeType {'
      'persons: $persons, '
      'isRemote: $isRemote, '
      'affiliations: $data'
      '}';
}

class UserOnboarded extends AffiliationState<Affiliation> {
  UserOnboarded({
    this.userId,
    required this.person,
    bool isRemote = false,
    required Affiliation affiliation,
  }) : super(affiliation!, isRemote: isRemote);

  final String? userId;
  final Person person;

  @override
  String toString() => '$runtimeType {'
      'userId: $userId, '
      'person: $person, '
      'affiliation: $data,'
      'isRemote: $isRemote '
      '}';
}

class AffiliationCreated extends AffiliationState<Affiliation> {
  AffiliationCreated(
    Affiliation affiliation, {
    bool isRemote = false,
  }) : super(affiliation, isRemote: isRemote);

  Person get person => data.person!;

  @override
  String toString() => '$runtimeType {'
      'person: $person, '
      'isRemote: $isRemote, '
      'affiliation: $data'
      '}';
}

class AffiliationUpdated extends AffiliationState<Affiliation> {
  AffiliationUpdated(
    Affiliation affiliation, {
    bool isRemote = false,
  }) : super(affiliation, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {affiliation: $data, isRemote: $isRemote}';
}

class AffiliationDeleted extends AffiliationState<Affiliation> {
  AffiliationDeleted(
    Affiliation affiliation, {
    bool isRemote = false,
  }) : super(affiliation, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {affiliation: $data, isRemote: $isRemote}';
}

class AffiliationPersonUpdated extends AffiliationState<Person> {
  final Person previous;
  final List<Affiliation> affiliations;
  AffiliationPersonUpdated(
    Person next,
    this.previous,
    this.affiliations, {
    bool isRemote = false,
  }) : super(next, isRemote: isRemote, props: [
          affiliations,
          previous,
        ]);

  @override
  String toString() => '$runtimeType {'
      'incident: $data, '
      'isRemote: $isRemote,'
      'previous: $previous,'
      'affiliations: $affiliations, '
      '}';
}

class OrganisationCreated extends AffiliationState<Organisation> {
  OrganisationCreated(
    Organisation organisation, {
    bool isRemote = false,
  }) : super(organisation, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, organisation: $data}';
}

class OrganisationUpdated extends AffiliationState<Organisation> {
  OrganisationUpdated(
    Organisation organisation, {
    bool isRemote = false,
  }) : super(organisation, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, organisation: $data}';
}

class OrganisationDeleted extends AffiliationState<Organisation> {
  OrganisationDeleted(
    Organisation organisation, {
    bool isRemote = false,
  }) : super(organisation, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, organisation: $data}';
}

class DivisionCreated extends AffiliationState<Division> {
  DivisionCreated(
    Division division, {
    bool isRemote = false,
  }) : super(division, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, division: $data}';
}

class DivisionUpdated extends AffiliationState<Division> {
  DivisionUpdated(
    Division division, {
    bool isRemote = false,
  }) : super(division, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, division: $data}';
}

class DivisionDeleted extends AffiliationState<Division> {
  DivisionDeleted(
    Division division, {
    bool isRemote = false,
  }) : super(division, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, division: $data}';
}

class DepartmentCreated extends AffiliationState<Department> {
  DepartmentCreated(
    Department department, {
    bool isRemote = false,
  }) : super(department, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, department: $data}';
}

class DepartmentUpdated extends AffiliationState<Department> {
  DepartmentUpdated(
    Department department, {
    bool isRemote = false,
  }) : super(department, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, department: $data}';
}

class DepartmentDeleted extends AffiliationState<Department> {
  DepartmentDeleted(
    Department department, {
    bool isRemote = false,
  }) : super(department, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {isRemote: $isRemote, department: $data}';
}

class AffiliationsUnloaded extends AffiliationState<Iterable<String?>?> {
  AffiliationsUnloaded({
    this.orgs,
    this.deps,
    this.divs,
    this.persons,
    Iterable<String?>? affiliations,
  }) : super(affiliations);

  final Iterable<String?>? orgs;
  final Iterable<String?>? deps;
  final Iterable<String?>? divs;
  final Iterable<String?>? persons;

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
    StackTrace? stackTrace,
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
  final StackTrace? stackTrace;
  final AffiliationCommand? command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
