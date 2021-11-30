import 'dart:async';

import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

class DepartmentRepositoryImpl extends StatefulRepository<String?, Department, DepartmentService>
    implements DepartmentRepository {
  DepartmentRepositoryImpl(
    DepartmentService service, {
    required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Department.uuid] from [value]
  @override
  String? toKey(Department? value) {
    return value?.uuid;
  }

  /// Create [Department] from json
  Department fromJson(Map<String, dynamic>? json) => DepartmentModel.fromJson(json!);

  /// Load departments
  Future<List<Department>> load({
    bool force = true,
    Completer<Iterable<Department>>? onRemote,
  }) async {
    await prepare(
      force: force,
    );
    return _load(
      onResult: onRemote,
    ) as FutureOr<List<Department>>;
  }

  /// GET ../departments
  Iterable<Department> _load({
    Completer<Iterable<Department>>? onResult,
  }) {
    return requestQueue!.load(
      service.getList,
      shouldEvict: true,
      onResult: onResult,
    );
  }

  @override
  Future<Iterable<Department>> onReset({Iterable<Department?>? previous = const []}) => Future.value(_load());

  @override
  Future<StorageState<Department>> onCreate(StorageState<Department> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body!;
    }
    throw DepartmentServiceException(
      'Failed to create Department ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Department>?> onUpdate(StorageState<Department> state) async {
    ServiceResponse<StorageState<Department>> response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw DepartmentServiceException(
      'Failed to update Department ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Department>?> onDelete(StorageState<Department> state) async {
    ServiceResponse<StorageState<Department>> response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw DepartmentServiceException(
      'Failed to delete Department ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class DepartmentServiceException implements Exception {
  DepartmentServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace? stackTrace;
  final ServiceResponse? response;

  @override
  String toString() {
    return 'DepartmentServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
