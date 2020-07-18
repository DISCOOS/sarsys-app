import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

class OperationRepositoryImpl extends ConnectionAwareRepository<String, Operation, OperationService>
    implements OperationRepository {
  OperationRepositoryImpl(
    OperationService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Operation> state) {
    return state?.value?.uuid;
  }

  /// Load operations
  Future<List<Operation>> load({bool force = true}) async {
    await prepare(
      force: force ?? false,
    );
    return _load();
  }

  /// Update [operation]
  Future<Operation> create(Operation operation) async {
    await prepare();
    return apply(
      StorageState.created(operation),
    );
  }

  /// Update [operation]
  Future<Operation> update(Operation operation) async {
    await prepare();
    return apply(
      StorageState.updated(operation),
    );
  }

  /// Delete [Operation] with given [uuid]
  Future<Operation> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// GET ../operations
  Future<List<Operation>> _load() async {
    if (connectivity.isOnline) {
      try {
        var response = await service.fetchAll();
        if (response.is200) {
          evict(
            retainKeys: response.body.map((operation) => operation.uuid),
          );
          response.body.forEach(
            (operation) => put(
              StorageState.created(
                operation,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw OperationServiceException(
          'Failed to load operations',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException catch (e) {
        // Assume offline
      }
    }
    return values;
  }

  @override
  Future<Iterable<Operation>> onReset() async => await _load();

  @override
  Future<Operation> onCreate(StorageState<Operation> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw OperationServiceException(
      'Failed to create Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Operation> onUpdate(StorageState<Operation> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw OperationServiceException(
      'Failed to update Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Operation> onDelete(StorageState<Operation> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw OperationServiceException(
      'Failed to delete Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class OperationServiceException implements Exception {
  OperationServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'OperationServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
