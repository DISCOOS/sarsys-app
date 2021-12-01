

import 'dart:async';

import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';

import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

class OperationRepositoryImpl extends StatefulRepository<String, Operation, OperationService>
    with StatefulCatchup<Operation, OperationService>
    implements OperationRepository {
  OperationRepositoryImpl(
    OperationService service, {
    required this.incidents,
    required ConnectivityService? connectivity,
  }) : super(
          service: service,
          dependencies: [incidents],
          connectivity: connectivity!,
        ) {
    // Handle messages
    // pushed from backend.
    catchupTo(service.messages);
  }

  /// Get [Incident] repository
  @override
  final IncidentRepository incidents;

  /// Get [Operation.uuid] from [value]
  @override
  String toKey(Operation? value) {
    return value!.uuid;
  }

  /// Create [Operation] from json
  Operation fromJson(Map<String, dynamic>? json) => OperationModel.fromJson(json!);

  /// Load operations
  Future<List<Operation?>> load({
    bool force = true,
    Completer<Iterable<Operation>>? onRemote,
  }) async {
    await prepare(
      force: force,
    );
    return _load(
      onRemote: onRemote,
    ) as FutureOr<List<Operation?>>;
  }

  /// GET ../operations
  Iterable<Operation> _load({
    Completer<Iterable<Operation>>? onRemote,
  }) {
    return requestQueue!.load(
      service.getList,
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<Iterable<Operation>> onReset({Iterable<Operation?>? previous}) => Future.value(_load());

  @override
  Future<StorageState<Operation>> onCreate(StorageState<Operation> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body!;
    }
    throw OperationServiceException(
      'Failed to create Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Operation>?> onUpdate(StorageState<Operation> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw OperationServiceException(
      'Failed to update Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Operation>?> onDelete(StorageState<Operation> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw OperationServiceException(
      'Failed to delete Operation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
