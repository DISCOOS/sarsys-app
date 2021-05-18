import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';

class DeviceRepositoryImpl extends StatefulRepository<String, Device, DeviceService> implements DeviceRepository {
  DeviceRepositoryImpl(
    DeviceService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        ) {
    //
    // Handle messages pushed from backend.
    //
    registerStreamSubscription(service.messages.listen(
      _processDeviceMessage,
    ));
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

  ///
  /// Handles messages pushed from server
  ///
  void _processDeviceMessage(DeviceMessage message) {
    if (isReady) {
      StorageState<Device> state;
      try {
        // Merge with local changes?
        if (containsKey(message.uuid)) {
          final previous = getState(message.uuid);
          // TODO: Peek to see if conflict will occur and handle it
          // Only apply if not modified locally
          if (previous.isRemote) {
            // TODO: Make this a generic reusable solution in StatefulRepository
            if (message.version == previous.version + 1) {
              final next = DeviceModel.fromJson(message.isState
                  ? message.state
                  : JsonPatch.apply(
                      previous.value.toJson(),
                      message.patches,
                      strict: false,
                    ));
              state = previous.isRemote
                  ? StorageState.updated(
                      next,
                      message.version,
                      isRemote: true,
                    )
                  : previous.replace(
                      next,
                      isRemote: false,
                    );
              put(state);
            } else if (message.version > previous.version + 1) {
              state = StorageState.updated(
                DeviceModel.fromJson(message.isState
                    ? message.state
                    : JsonPatch.apply(
                        previous.value.toJson(),
                        message.patches,
                        strict: false,
                      )),
                message.version,
                isRemote: true,
              );
              put(state);
            }
          }
        } else if (message.type == 'DeviceCreated') {
          final next = DeviceModel.fromJson(
            message.isState
                ? message.state
                : JsonPatch.apply(
                    {},
                    message.patches,
                    strict: false,
                  ),
          );
          state = StorageState.created(
            next,
            message.version,
            isRemote: true,
          );
          put(state);
        }
      } on Exception catch (error, stackTrace) {
        if (state != null) {
          put(state.failed(error));
        }
        onError(error, stackTrace);
      }
    }
  }
}
