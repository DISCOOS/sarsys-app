import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/services/service.dart';

abstract class DeviceRepository implements ConnectionAwareRepository<String, Device> {
  /// [Device] service
  DeviceService get service;

  /// Get [Incident.uuid]
  String get iuuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Device] is
  /// created with [create].
  @override
  bool get isReady;

  /// Load all devices for given [Incident.uuid]
  Future<List<Device>> load(String iuuid);

  /// Create [device]
  Future<Device> create(String iuuid, Device device);

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
