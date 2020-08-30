import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/repository.dart';

abstract class OrganisationRepository implements ConnectionAwareRepository<String, Organisation, OrganisationService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Organisation> state) {
    return state?.value?.uuid;
  }

  /// Load organisations
  Future<List<Organisation>> load({
    bool force = true,
    Completer<Iterable<Organisation>> onRemote,
  });
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
