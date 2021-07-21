// @dart=2.11

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';

class DeviceRepositoryImpl extends StatefulRepository<String, Device, DeviceService>
    with StatefulCatchup<Device, DeviceService>
    implements DeviceRepository {
  DeviceRepositoryImpl(
    DeviceService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        ) {
    // Handle messages
    // pushed from backend.
    catchupTo(service.messages);
  }

  /// Get [Device.uuid] from [value]
  @override
  String toKey(Device value) {
    return value?.uuid;
  }

  /// Create [Device] from json
  Device fromJson(Map<String, dynamic> json) => DeviceModel.fromJson(json);

  /// Load all devices
  Future<Iterable<Device>> load({
    Completer<Iterable<Device>> onRemote,
  }) async {
    await prepare();
    return _load(
      onRemote: onRemote,
    );
  }

  /// Get [Device] count
  int count({
    List<DeviceStatus> exclude: const [DeviceStatus.unavailable],
  }) =>
      exclude?.isNotEmpty == false
          ? length
          : values
              .where(
                (device) => !exclude.contains(device.status),
              )
              .length;

  Iterable<Device> _load({Completer<Iterable<Device>> onRemote}) {
    return requestQueue.load(
      service.getList,
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<Iterable<Device>> onReset({Iterable<Device> previous}) => Future.value(_load());

  @override
  Future<StorageState<Device>> onCreate(StorageState<Device> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body;
    }
    throw DeviceServiceException(
      'Failed to create Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Device>> onUpdate(StorageState<Device> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw DeviceServiceException(
      'Failed to update Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Device>> onDelete(StorageState<Device> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw DeviceServiceException(
      'Failed to delete Device ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
