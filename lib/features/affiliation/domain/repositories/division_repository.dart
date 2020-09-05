import 'dart:async';

import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class DivisionRepository implements ConnectionAwareRepository<String, Division, DivisionService> {
  /// Get [Division.uuid] from [state]
  @override
  String toKey(StorageState<Division> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Division>> load({
    bool force = true,
    Completer<Iterable<Division>> onRemote,
  });
}

class DivisionServiceException extends ServiceException {
  DivisionServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
