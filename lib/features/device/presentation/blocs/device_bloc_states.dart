

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';

/// ---------------------
/// Normal States
/// ---------------------
abstract class DeviceState<T> extends PushableBlocEvent<T> {
  DeviceState(
    T data, {
    StackTrace? stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data,
          props: [...props, isRemote],
          stackTrace: stackTrace,
          isRemote: isRemote,
        );

  bool isError() => this is DeviceBlocError;
  bool isEmpty() => this is DevicesEmpty;
  bool isLoaded() => this is DevicesLoaded;
  bool isCreated() => this is DeviceCreated;
  bool isUpdated() => this is DeviceUpdated;
  bool isDeleted() => this is DeviceDeleted;
  bool isUnloaded() => this is DevicesUnloaded;

  bool isAvailable() => (data is Device) ? (data as Device).status == DeviceStatus.available : false;
  bool isUnavailable() => (data is Device) ? (data as Device).status == DeviceStatus.unavailable : false;

  bool isStatusChanged() => false;
  bool isLocationChanged() => false;
}

class DevicesEmpty extends DeviceState<Null> {
  DevicesEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class DevicesLoaded extends DeviceState<List<String?>> {
  DevicesLoaded(
    List<String?> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {devices: $data, isRemote: $isRemote}';
}

class DeviceCreated extends DeviceState<Device> {
  DeviceCreated(
    Device device, {
    bool isRemote = false,
  }) : super(device, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {device: $data, isRemote: $isRemote}';
}

class DeviceUpdated extends DeviceState<Device> {
  DeviceUpdated(
    Device device,
    this.previous, {
    bool isRemote = false,
  }) : super(
          device,
          props: [previous],
          isRemote: isRemote,
        );
  final Device previous;

  bool isChanged() => data != previous;
  bool isStatusChanged() => data!.status != previous?.status;
  bool isLocationChanged() => data!.position != previous?.position;

  @override
  String toString() => '$runtimeType {device: $data, previous: $previous, isRemote: $isRemote}';
}

class DeviceDeleted extends DeviceState<Device> {
  DeviceDeleted(
    Device device, {
    bool isRemote = false,
  }) : super(device, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {device: $data, isRemote: $isRemote}';
}

class DevicesUnloaded extends DeviceState<Iterable<Device>> {
  DevicesUnloaded(Iterable<Device> devices) : super(devices);

  @override
  String toString() => '$runtimeType {devices: $data}';
}

/// ---------------------
/// Error states
/// ---------------------

class DeviceBlocError extends DeviceState<Object> {
  DeviceBlocError(
    Object error, {
    StackTrace? stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class DeviceBlocException implements Exception {
  DeviceBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final Object? command;
  final DeviceState state;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
