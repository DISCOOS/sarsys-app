import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

class PersonnelRepositoryImpl extends ConnectionAwareRepository<String, Personnel> implements PersonnelRepository {
  PersonnelRepositoryImpl(
    this.service, {
    @required ConnectivityService connectivity,
  }) : super(
          connectivity: connectivity,
        );

  /// [Personnel] service
  final PersonnelService service;

  /// Get [Incident.uuid]
  String get iuuid => _iuuid;
  String _iuuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _iuuid != null;

  /// Get [Personnel.uuid] from [state]
  @override
  String toKey(StorageState<Personnel> state) {
    return state.value.uuid;
  }

  /// Ensure that box for given [Incident.uuid] is open
  Future<void> _ensure(String iuuid) async {
    if (isEmptyOrNull(iuuid)) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    if (_iuuid != iuuid) {
      await prepare(
        force: true,
        postfix: iuuid,
      );
      _iuuid = iuuid;
    }
  }

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
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
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      values
          .where((personnel) => !exclude.contains(personnel.status))
          .where((personnel) => personnel.userId == user.userId);

  /// GET ../personnels
  Future<List<Personnel>> load(String iuuid) async {
    await _ensure(iuuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(iuuid);
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
          'Failed to fetch personnel for incident $iuuid',
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
  Future<Personnel> create(String iuuid, Personnel personnel) async {
    await _ensure(iuuid);
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
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, personnel.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
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

  /// Unload all devices for given [iuuid]
  Future<List<Personnel>> close() async {
    _iuuid = null;
    return super.close();
  }

  @override
  Future<Personnel> onCreate(StorageState<Personnel> state) async {
    var response = await service.create(_iuuid, state.value);
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
