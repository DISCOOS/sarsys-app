import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/services/service.dart';

abstract class PersonnelRepository implements ConnectionAwareRepository<String, Personnel> {
  /// [Personnel] service
  PersonnelService get service;

  /// Get [Incident.uuid]
  String get iuuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady;

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  });

  /// Find personnel from user
  Iterable<Personnel> find(
    User user, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  });

  /// GET ../personnels
  Future<List<Personnel>> load(String iuuid);

  /// Create [personnel]
  Future<Personnel> create(String iuuid, Personnel personnel);

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
