import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/core/domain/box_repository.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';

abstract class IncidentRepository implements BoxRepository<String, Incident, IncidentService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Incident> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Incident>> load({
    bool force = true,
    Completer<Iterable<Incident>> onRemote,
  });
}

class IncidentServiceException extends ServiceException {
  IncidentServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'IncidentServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
