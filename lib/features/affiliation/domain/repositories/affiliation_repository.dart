import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/core/repository.dart';

abstract class AffiliationRepository implements ConnectionAwareRepository<String, Affiliation, AffiliationService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Affiliation> state) {
    return state?.value?.uuid;
  }

  /// Find [Affiliation]s for affiliate with given [Person.uuid]
  Iterable<Affiliation> findPerson(String puuid);

  /// Find [Affiliation]s matching given query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)});

  /// Load given affiliations
  Future<List<Affiliation>> load(
    List<String> uuids, {
    bool force = true,
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
