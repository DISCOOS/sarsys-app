import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/core/repository.dart';

class DepartmentRepositoryImpl extends ConnectionAwareRepository<String, Department, DepartmentService>
    implements DepartmentRepository {
  DepartmentRepositoryImpl(
    DepartmentService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Department.uuid] from [state]
  @override
  String toKey(StorageState<Department> state) {
    return state?.value?.uuid;
  }

  /// Load departments
  Future<List<Department>> load({bool force = true}) async {
    await prepare(
      force: force ?? false,
    );
    return _load();
  }

  /// Update [department]
  Future<Department> create(Department department) async {
    await prepare();
    return apply(
      StorageState.created(department),
    );
  }

  /// Update [department]
  Future<Department> update(Department department) async {
    await prepare();
    return apply(
      StorageState.updated(department),
    );
  }

  /// Delete [Department] with given [uuid]
  Future<Department> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// GET ../departments
  Future<List<Department>> _load() async {
    if (connectivity.isOnline) {
      try {
        var response = await service.fetchAll();
        if (response.is200) {
          evict(
            retainKeys: response.body.map((department) => department.uuid),
          );
          response.body.forEach(
            (department) => put(
              StorageState.created(
                department,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw DepartmentServiceException(
          'Failed to load departments',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  @override
  Future<Iterable<Department>> onReset() async => await _load();

  @override
  Future<Department> onCreate(StorageState<Department> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DepartmentServiceException(
      'Failed to create Department ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Department> onUpdate(StorageState<Department> state) async {
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
    throw DepartmentServiceException(
      'Failed to update Department ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Department> onDelete(StorageState<Department> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'DepartmentServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
