import 'package:SarSys/core/repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/services/service.dart';

abstract class DivisionRepository implements ConnectionAwareRepository<String, Division, DivisionService> {
  /// Get [Division.uuid] from [state]
  @override
  String toKey(StorageState<Division> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Division>> load({bool force = true});

  /// Update [incident]
  Future<Division> create(Division incident);

  /// Update [incident]
  Future<Division> update(Division incident);

  /// Delete [Division] with given [uuid]
  Future<Division> delete(String uuid);
}

class DivisionServiceException implements Exception {
  DivisionServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
