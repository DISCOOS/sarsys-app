import 'dart:async';

import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class PersonnelRepository implements StatefulRepository<String, Personnel, PersonnelService> {
  /// Get [Operation.uuid]
  String get ouuid;

  /// Get [Unit] repository
  UnitRepository get units;

  /// Get [Affiliation] repository
  AffiliationRepository get affiliations;

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
    bool Function(Personnel personnel) where,
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  });

  /// GET ../personnels
  Future<List<Personnel>> load(
    String ouuid, {
    Completer<Iterable<Personnel>> onRemote,
  });
}

class PersonnelServiceException extends ServiceException {
  PersonnelServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}
