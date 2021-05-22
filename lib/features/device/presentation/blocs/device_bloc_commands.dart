import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class DeviceCommand<S, T> extends BlocCommand<S, T> {
  DeviceCommand(S data, [props = const []]) : super(data, props);
}

class LoadDevices extends DeviceCommand<void, Iterable<Device>> {
  LoadDevices() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class CreateDevice extends DeviceCommand<Device, Device> {
  CreateDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class UpdateDevice extends DeviceCommand<Device, Device> {
  UpdateDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class DeleteDevice extends DeviceCommand<Device, Device> {
  DeleteDevice(Device data) : super(data);

  @override
  String toString() => '$runtimeType {device: $data}';
}

class UnloadDevices extends DeviceCommand<void, Iterable<Device>> {
  UnloadDevices() : super(null);

  @override
  String toString() => '$runtimeType {}';
}
