import 'dart:async';

import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class DepartmentRepository implements ConnectionAwareRepository<String, Department, DepartmentService> {
  /// Get [Department.uuid] from [state]
  @override
  String toKey(StorageState<Department> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Department>> load({
    bool force = true,
    Completer<Iterable<Department>> onRemote,
  });
}

class DepartmentServiceException implements Exception {
  DepartmentServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
