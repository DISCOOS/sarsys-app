import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/repository.dart';

import 'person_repository.dart';
import 'department_repository.dart';
import 'division_repository.dart';
import 'organisation_repository.dart';

abstract class AffiliationRepository implements ConnectionAwareRepository<String, Affiliation, AffiliationService> {
  /// [Organisation] repository
  OrganisationRepository get orgs;

  /// [Division] repository
  DivisionRepository get divs;

  /// [Department] repository
  DepartmentRepository get deps;

  /// [Person] repository
  PersonRepository get persons;

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Affiliation> state) {
    return state?.value?.uuid;
  }

  /// Find [Affiliation]s for affiliate with given [Person.uuid]
  Iterable<Affiliation> findPerson(String puuid);

  /// Find [Affiliation]s matching given query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)});

  /// Fetch given affiliations
  Future<List<Affiliation>> fetch(
    List<String> uuids, {
    bool replace = false,
  });

  /// Search for affiliations matching given [filter]
  /// from [repo.service] and store matches in [repo]
  Future<List<Affiliation>> search(
    String filter, {
    int limit,
    int offset,
  });

  /// Init from local storage, overwrite states
  /// with given affiliations if given. Returns
  /// number of states after initialisation
  Future<int> init({List<Affiliation> affiliations});

  /// Create [Affiliation] with existing [Person]
  Future<Affiliation> create(Affiliation affiliation);

  /// Update [Affiliation]
  Future<Affiliation> update(Affiliation affiliation);

  /// Delete [Affiliation] with given [uuid]
  Future<Affiliation> delete(String uuid);
}

class AffiliationServiceException implements Exception {
  AffiliationServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
