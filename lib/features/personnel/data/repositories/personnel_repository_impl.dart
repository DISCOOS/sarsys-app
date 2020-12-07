import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';

class PersonnelRepositoryImpl extends StatefulRepository<String, Personnel, PersonnelService>
    implements PersonnelRepository {
  PersonnelRepositoryImpl(
    PersonnelService service, {
    @required this.units,
    @required this.affiliations,
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
          dependencies: [units, affiliations],
        );

  /// Get [Operation.uuid]
  String get ouuid => _ouuid;
  String _ouuid;

  /// Get [Unit] repository
  final UnitRepository units;

  /// Get [Affiliation] repository
  final AffiliationRepository affiliations;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _ouuid != null;

  /// Get [Personnel.uuid] from [state]
  @override
  String toKey(StorageState<Personnel> state) {
    return state.value.uuid;
  }

  /// Create [Personnel] from json
  Personnel fromJson(Map<String, dynamic> json) => PersonnelModel.fromJson(json);

  /// Open repository for given [Incident.uuid]
  Future<Iterable<Personnel>> open(String ouuid) async {
    if (isEmptyOrNull(ouuid)) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    if (_ouuid != ouuid) {
      await prepare(
        force: true,
        postfix: ouuid,
      );
      _ouuid = ouuid;
    }
    return values;
  }

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      exclude?.isNotEmpty == false
          ? length
          : values
              .where(
                (personnel) => !exclude.contains(personnel.status),
              )
              .length;

  /// Find personnel from user
  Iterable<Personnel> findUser(
    String userId, {
    bool Function(Personnel personnel) where,
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      values
          .where((personnel) => !exclude.contains(personnel.status))
          .where((personnel) => where == null || where(personnel))
          .where((personnel) => personnel.userId == userId);

  /// GET ../personnels
  Future<List<Personnel>> load(
    String ouuid, {
    Completer<Iterable<Personnel>> onRemote,
  }) async {
    await open(ouuid);
    return requestQueue.load(
      () => service.getListFromId(ouuid),
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  /// Unload all devices for given [ouuid]
  Future<List<Personnel>> close() async {
    _ouuid = null;
    return super.close();
  }

  @override
  Future<Iterable<Personnel>> onReset({Iterable<Personnel> previous}) =>
      _ouuid != null ? load(_ouuid) : Future.value(previous);

  @override
  Future<Personnel> onCreate(StorageState<Personnel> state) async {
    var response = await service.create(_ouuid, state.value);
    if (response.is201) {
      return state.value;
    }
    throw PersonnelServiceException(
      'Failed to create Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Personnel> onUpdate(StorageState<Personnel> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    }
    throw PersonnelServiceException(
      'Failed to update Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Personnel> onDelete(StorageState<Personnel> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    }
    throw PersonnelServiceException(
      'Failed to delete Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
