import 'package:SarSys/services/service.dart';

import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';

abstract class UnitRepository implements ConnectionAwareRepository<String, Unit> {
  /// [UnitService] service
  UnitService get service;

  /// Get [Incident.uuid]
  String get ouuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady;

  /// Get [Unit] count
  int count({
    UnitType type,
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  });

  /// Find unit from personnel
  Iterable<Unit> find(
    Personnel personnel, {
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  });

  /// Find and replace given [Personnel]
  Unit findAndReplace(Personnel personnel);

  /// Find and remove given [Personnel]
  Unit findAndRemove(Personnel personnel);

  /// Get next available [Unit.number]
  int nextAvailableNumber(UnitType type, {bool reuse = true});

  /// GET ../units
  Future<List<Unit>> load(String ouuid);

  /// Create [unit]
  Future<Unit> create(String ouuid, Unit unit);

  /// Update [unit]
  Future<Unit> update(Unit unit);

  /// PUT ../devices/{deviceId}
  Future<Unit> patch(Unit unit);

  /// Delete [Unit] with given [uuid]
  Future<Unit> delete(String uuid);
}

class UnitServiceException implements Exception {
  UnitServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'UnitServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
