

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class UnitCommand<S, T> extends BlocCommand<S, T> {
  UnitCommand(S data, [props = const []]) : super(data, props);
}

class LoadUnits extends UnitCommand<String?, List<Unit>> {
  LoadUnits(String? ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}

class CreateUnit extends UnitCommand<Unit, Unit> {
  CreateUnit(
    Unit data, {
    this.position,
    this.devices,
  }) : super(data, [position, devices]);

  final Position? position;
  final List<Device>? devices;

  @override
  String toString() => '$runtimeType {'
      'unit: $data, '
      'position: $position, '
      'devices: $devices}';
}

class UpdateUnit extends UnitCommand<Unit?, Unit> {
  UpdateUnit(Unit? data) : super(data);

  @override
  String toString() => '$runtimeType {unit: $data}';
}

class DeleteUnit extends UnitCommand<Unit?, Unit> {
  DeleteUnit(Unit? data) : super(data);

  @override
  String toString() => '$runtimeType {unit: $data}';
}

class UnloadUnits extends UnitCommand<String?, List<Unit>> {
  UnloadUnits(String? ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}
