import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';

class DeviceRepository extends ConnectionAwareRepository<String, Device> {
  DeviceRepository(
    this.service, {
    @required ConnectivityService connectivity,
  }) : super(
          connectivity: connectivity,
        );

  /// [Device] service
  final DeviceService service;

  /// Get [Incident.uuid]
  String get iuuid => _iuuid;
  String _iuuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Device] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _iuuid != null;

  /// Get [Device.uuid] from [state]
  @override
  String toKey(StorageState<Device> state) {
    return state.value.uuid;
  }

  /// Ensure that box for given iuuid is open
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

  /// Load all devices for given [Incident.uuid]
  Future<List<Device>> load(String iuuid) async {
    await _ensure(iuuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(iuuid);
        if (response.is200) {
          evict(
            retainKeys: response.body.map((device) => device.uuid),
          );
          response.body.forEach(
            (incident) => commit(
              StorageState.created(
                incident,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw DeviceServiceException(
          'Failed to fetch devices for incident $iuuid',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  /// Create [device]
  Future<Device> create(String iuuid, Device device) async {
    await _ensure(iuuid);
    return apply(
      StorageState.created(device),
    );
  }

  /// Update [device]
  Future<Device> update(Device device) async {
    checkState();
    return apply(
      StorageState.updated(device),
    );
  }

  /// PUT ../devices/{deviceId}
  Future<Device> patch(Device device) async {
    checkState();
    final old = this[device.uuid];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, device.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    return update(
      Device.fromJson(newJson..addAll({'uuid': device.uuid})),
    );
  }

  /// Delete [Device] with given [uuid]
  Future<Device> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// Unload all devices for given [iuuid]
  Future<List<Device>> close() async {
    _iuuid = null;
    return super.close();
  }

  @override
  Future<Device> onCreate(StorageState<Device> state) async {
    var response = await service.create(_iuuid, state.value);
    if (response.is200) {
      return response.body;
    }
    throw DeviceServiceException(
      'Failed to create Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Device> onUpdate(StorageState<Device> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    }
    throw DeviceServiceException(
      'Failed to update Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Device> onDelete(StorageState<Device> state) async {
    var response = await service.delete(state.value);
    if (response.is204) {
      return state.value;
    }
    throw DeviceServiceException(
      'Failed to delete Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class DeviceServiceException implements Exception {
  DeviceServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'DeviceServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
