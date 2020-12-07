import 'dart:async';

import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/data/services/service.dart';

import 'incident_repository.dart';

abstract class OperationRepository implements StatefulRepository<String, Operation, OperationService> {
  /// Operation service
  OperationService get service;

  /// Get [Incident] repository
  IncidentRepository get incidents;

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Operation> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Operation>> load({
    bool force = true,
    Completer<Iterable<Operation>> onRemote,
  });
}

class OperationServiceException extends ServiceException {
  OperationServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
