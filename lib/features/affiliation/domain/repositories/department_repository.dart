import 'dart:async';

import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class DepartmentRepository implements StatefulRepository<String, Department, DepartmentService> {
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

class DepartmentServiceException extends ServiceException {
  DepartmentServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
