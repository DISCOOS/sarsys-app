

import 'dart:async';

import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

abstract class OrganisationRepository implements StatefulRepository<String?, Organisation, OrganisationService> {
  /// Get [Operation.uuid] from [value]
  @override
  String? toKey(Organisation? value) {
    return value?.uuid;
  }

  /// Load organisations
  Future<List<Organisation?>> load({
    bool force = true,
    Completer<Iterable<Organisation>>? onRemote,
  });
}

class OrganisationServiceException extends ServiceException {
  OrganisationServiceException(
    Object error, {
    ServiceResponse? response,
    StackTrace? stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
