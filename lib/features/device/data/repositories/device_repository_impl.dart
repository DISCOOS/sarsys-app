import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/service.dart';

class DeviceRepositoryImpl extends ConnectionAwareRepository<String, Device> implements DeviceRepository {
  DeviceRepositoryImpl(
    this.service, {
    @required ConnectivityService connectivity,
  }) : super(
          connectivity: connectivity,
        ) {
    //
    // Handle messages pushed from backend.
    //
    registerStreamSubscription(service.messages.listen(
      _processDeviceMessage,
    ));
  }

  /// [Device] service
  final DeviceService service;

  /// Get [Device.uuid] from [state]
  @override
  String toKey(StorageState<Device> state) {
    return state.value.uuid;
  }

  /// Load all devices for given [Incident.uuid]
  Future<List<Device>> load() async {
    await prepare();
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch();
        if (response.is200) {
          evict(
            retainKeys: response.body.map((device) => device.uuid),
          );
          response.body.forEach(
            (incident) => put(
              StorageState.created(
                incident,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw DeviceServiceException(
          'Failed to fetch devices',
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
  Future<Device> create(Device device) async {
    await prepare();
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
    DeviceModel next = _patch(device);
    return update(next);
  }

  /// Delete [Device] with given [uuid]
  Future<Device> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  @override
  Future<Iterable<Device>> onReset() async => await load();

  @override
  Future<Device> onCreate(StorageState<Device> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DeviceServiceException(
      'Failed to update Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Device> onDelete(StorageState<Device> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DeviceServiceException(
      'Failed to delete Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  DeviceModel _patch(Device device) {
    final old = this[device.uuid];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, device.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    final updated = DeviceModel.fromJson(
      newJson..addAll({'uuid': device.uuid}),
    );
    return updated;
  }

  ///
  /// Handles messages pushed from server
  ///
  void _processDeviceMessage(DeviceMessage message) {
    if (hasSubscriptions) {
      var state;
      try {
        switch (message.type) {
          case DeviceMessageType.LocationChanged:
            if (containsKey(message.duuid)) {
              final previous = getState(message.duuid);
              // Merge with local changes
              final next = _patch(
                DeviceModel.fromJson(message.json),
              );
              state = previous.isRemote ? StorageState.updated(next, remote: true) : previous.replace(next);
              put(state);
            }
            break;
        }
      } on Exception catch (error, stackTrace) {
        if (state) {
          put(state.failed(error));
        }
        onError(error, stackTrace);
      }
    }
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
