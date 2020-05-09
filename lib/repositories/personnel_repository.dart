import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';

class PersonnelRepository extends ConnectionAwareRepository<String, Personnel> {
  PersonnelRepository(
    this.service, {
    @required ConnectivityService connectivity,
    int compactWhen = 10,
  }) : super(
          connectivity: connectivity,
          compactWhen: compactWhen,
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
  List<Personnel> find(
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
          await clear();
          await Future.wait(response.body.map(
            (personnel) => commit(
              StorageState.pushed(
                personnel,
              ),
            ),
          ));
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
      StorageState.changed(personnel),
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
      Personnel.fromJson(newJson..addAll({'uuid': personnel.uuid})),
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
  Future<List<Personnel>> unload() async {
    final devices = await clear();
    _iuuid = null;
    return devices;
  }

  @override
  Future<Personnel> onCreate(StorageState<Personnel> state) async {
    var response = await service.create(_iuuid, state.value);
    if (response.is200) {
      return response.body;
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
    }
    throw PersonnelServiceException(
      'Failed to update Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Personnel> onDelete(StorageState<Personnel> state) async {
    var response = await service.delete(state.value);
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
