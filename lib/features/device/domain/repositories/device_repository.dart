

import 'dart:async';

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class DeviceRepository implements StatefulRepository<String, Device, DeviceService> {
  /// [Device] service
  DeviceService get service;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Device] is
  /// created with [create].
  @override
  bool get isReady;

  /// Load all devices
  Future<Iterable<Device>> load({
    Completer<Iterable<Device>>? onRemote,
  });

  /// Get [Device] count
  int count({
    List<DeviceStatus> exclude: const [DeviceStatus.unavailable],
  });
}

class DeviceServiceException extends ServiceException {
  DeviceServiceException(
    Object error, {
    ServiceResponse? response,
    StackTrace? stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'DeviceServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
