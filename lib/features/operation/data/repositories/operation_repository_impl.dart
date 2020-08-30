import 'dart:async';

import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

class OperationRepositoryImpl extends ConnectionAwareRepository<String, Operation, OperationService>
    implements OperationRepository {
  OperationRepositoryImpl(
    OperationService service, {
    @required this.incidents,
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          dependencies: [incidents],
          connectivity: connectivity,
        );

  /// Get [Incident] repository
  @override
  final IncidentRepository incidents;

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Operation> state) {
    return state?.value?.uuid;
  }

  /// Create [Operation] from json
  Operation fromJson(Map<String, dynamic> json) => OperationModel.fromJson(json);

  /// Load operations
  Future<List<Operation>> load({
    bool force = true,
    Completer<Iterable<Operation>> onRemote,
  }) async {
    await prepare(
      force: force ?? false,
    );
    return _load(
      onRemote: onRemote,
    );
  }

  /// GET ../operations
  Future<List<Operation>> _load({
    Completer<Iterable<Operation>> onRemote,
  }) async {
    scheduleLoad(
      service.fetchAll,
      shouldEvict: true,
      onResult: onRemote,
    );
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
