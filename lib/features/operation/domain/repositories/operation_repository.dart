import 'dart:async';

import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/data/services/service.dart';

import 'incident_repository.dart';

abstract class OperationRepository implements ConnectionAwareRepository<String, Operation, OperationService> {
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

class OperationServiceException implements Exception {
  OperationServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
