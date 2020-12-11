import 'dart:async';

import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

import 'person_repository.dart';
import 'department_repository.dart';
import 'division_repository.dart';
import 'organisation_repository.dart';

abstract class AffiliationRepository implements StatefulRepository<String, Affiliation, AffiliationService> {
  /// [Organisation] repository
  OrganisationRepository get orgs;

  /// [Division] repository
  DivisionRepository get divs;

  /// [Department] repository
  DepartmentRepository get deps;

  /// [Person] repository
  PersonRepository get persons;

  /// Get [Operation.uuid] from [value]
  @override
  String toKey(Affiliation value) {
    return value?.uuid;
  }

  /// Find [Affiliation]s for affiliate with given [Person.uuid]
  Iterable<Affiliation> findPerson(String puuid);

  /// Find [Affiliation]s matching given query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)});

  /// Init from local storage, overwrite states
  /// with given affiliations if given. Returns
  /// affiliation after initialisation
  Future<List<Affiliation>> load({
    bool force = true,
    Completer<Iterable<Affiliation>> onRemote,
  });

  /// Fetch given affiliations
  Future<List<Affiliation>> fetch(
    List<String> uuids, {
    bool replace = false,
    Completer<Iterable<Affiliation>> onRemote,
  });

  /// Search for affiliations matching given [filter]
  /// from [repo.service] and store matches in [repo]
  Future<List<Affiliation>> search(
    String filter, {
    int limit,
    int offset,
  });
}

class AffiliationServiceException extends ServiceException {
  AffiliationServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
