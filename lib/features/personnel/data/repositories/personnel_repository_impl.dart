import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';

class PersonnelRepositoryImpl extends ConnectionAwareRepository<String, Personnel> implements PersonnelRepository {
  PersonnelRepositoryImpl(
    this.service, {
    @required ConnectivityService connectivity,
  }) : super(
          connectivity: connectivity,
        );

  /// [Personnel] service
  final PersonnelService service;

  /// Get [Operation.uuid]
  String get ouuid => _ouuid;
  String _ouuid;

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

  /// Ensure that box for given [Incident.uuid] is open
  Future<void> _ensure(String ouuid) async {
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
  Iterable<Personnel> find(
    User user, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      values
          .where((personnel) => !exclude.contains(personnel.status))
          .where((personnel) => personnel.userId == user.userId);

  /// GET ../personnels
  Future<List<Personnel>> load(String ouuid) async {
    await _ensure(ouuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(ouuid);
        if (response.is200) {
          evict(
            retainKeys: response.body.map((personnel) => personnel.uuid),
          );

          response.body.forEach(
            (personnel) => put(
              StorageState.created(
                personnel,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw PersonnelServiceException(
          'Failed to fetch personnel for incident $ouuid',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  /// Create [personnel]
  Future<Personnel> create(String ouuid, Personnel personnel) async {
    await _ensure(ouuid);
    return apply(
      StorageState.created(personnel),
    );
  }

  /// Update [personnel]
  Future<Personnel> update(Personnel personnel) async {
    checkState();
    return apply(
      StorageState.updated(personnel),
    );
  }

  /// PUT ../devices/{deviceId}
  Future<Personnel> patch(Personnel personnel) async {
    checkState();
    final old = this[personnel.uuid];
    final newJson = JsonUtils.patch(old, personnel);
    return update(
      PersonnelModel.fromJson(newJson..addAll({'uuid': personnel.uuid})),
    );
  }

  /// Delete [Personnel] with given [uuid]
  Future<Personnel> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// Unload all devices for given [ouuid]
  Future<List<Personnel>> close() async {
    _ouuid = null;
    return super.close();
  }

  @override
  Future<Iterable<Personnel>> onReset() => _ouuid != null ? load(_ouuid) : values;

  @override
  Future<Personnel> onCreate(StorageState<Personnel> state) async {
    var response = await service.create(_ouuid, state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw PersonnelServiceException(
      'Failed to delete Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
