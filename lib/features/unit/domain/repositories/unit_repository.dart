// @dart=2.11

import 'dart:async';

import 'package:SarSys/core/data/services/service.dart';

import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';

abstract class UnitRepository implements StatefulRepository<String, Unit, UnitService> {
  /// Get [Operation.uuid]
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
    List<UnitStatus> exclude: const [UnitStatus.retired],
  });

  /// Find unit from personnel
  Iterable<Unit> findPersonnel(
    String puuid, {
    List<UnitStatus> exclude: const [UnitStatus.retired],
  });

  /// Get next available [Unit.number]
  int nextAvailableNumber(UnitType type, {bool reuse = true});

  /// GET ../units
  Future<List<Unit>> load(
    String ouuid, {
    Completer<Iterable<Unit>> onRemote,
  });
}

class UnitServiceException extends ServiceException {
  UnitServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
