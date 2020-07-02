import 'package:SarSys/core/repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/services/service.dart';

abstract class OperationRepository implements ConnectionAwareRepository<String, Operation, OperationService> {
  /// Operation service
  OperationService get service;

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Operation> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Operation>> load({bool force = true});

  /// Update [operation]
  Future<Operation> create(Operation operation);

  /// Update [operation]
  Future<Operation> update(Operation operation);

  /// Delete [Operation] with given [uuid]
  Future<Operation> delete(String uuid);
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
