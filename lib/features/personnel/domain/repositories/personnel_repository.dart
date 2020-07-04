import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/services/service.dart';

abstract class PersonnelRepository implements ConnectionAwareRepository<String, Personnel, PersonnelService> {
  /// Get [Operation.uuid]
  String get ouuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady;

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  });

  /// Find personnel from user
  Iterable<Personnel> findUser(
    String userId, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  });

  /// GET ../personnels
  Future<List<Personnel>> load(String ouuid);

  /// Create [personnel]
  Future<Personnel> create(String ouuid, Personnel personnel);

  /// Update [personnel]
  Future<Personnel> update(Personnel personnel);

  /// PUT ../devices/{deviceId}
  Future<Personnel> patch(Personnel personnel);

  /// Delete [Personnel] with given [uuid]
  Future<Personnel> delete(String uuid);
}

class PersonnelServiceException implements Exception {
  PersonnelServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'PersonnelServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
