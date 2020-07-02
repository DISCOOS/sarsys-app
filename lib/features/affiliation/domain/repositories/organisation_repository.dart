import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/core/repository.dart';

abstract class OrganisationRepository implements ConnectionAwareRepository<String, Organisation, OrganisationService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Organisation> state) {
    return state?.value?.uuid;
  }

  /// Load organisations
  Future<List<Organisation>> load({bool force = true});

  /// Update [Organisation]
  Future<Organisation> create(Organisation organisation);

  /// Update [Organisation]
  Future<Organisation> update(Organisation organisation);

  /// Delete [Organisation] with given [uuid]
  Future<Organisation> delete(String uuid);
}

class OrganisationServiceException implements Exception {
  OrganisationServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
