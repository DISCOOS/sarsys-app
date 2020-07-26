import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/services/service.dart';

abstract class DeviceRepository implements ConnectionAwareRepository<String, Device, DeviceService> {
  /// [Device] service
  DeviceService get service;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Device] is
  /// created with [create].
  @override
  bool get isReady;

  /// Load all devices for given [Incident.uuid]
  Future<List<Device>> load();

  /// Create [device]
  Future<Device> create(Device device);

  /// Update [device]
  Future<Device> update(Device device);

  /// PUT ../devices/{deviceId}
  Future<Device> patch(Device device);

  /// Delete [Device] with given [uuid]
  Future<Device> delete(String uuid);
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
