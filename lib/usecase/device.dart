import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/device_editor.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DeviceParams extends BlocParams<DeviceBloc, Device> {
  final Unit unit;
  DeviceParams({Device device, this.unit}) : super(device);
}

/// Create an device
Future<dartz.Either<bool, Device>> createDevice() => CreateDevice()(DeviceParams());

class CreateDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    var result = await showDialog<Device>(
      context: params.overlay.context,
      builder: (context) => DeviceEditor(
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);

    final device = await params.bloc.create(result);
    return dartz.Right(device);
  }
}

/// Attach an device to incident
Future<dartz.Either<bool, Device>> attachDevice() => AttachDevice()(DeviceParams());

class AttachDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    var result = await prompt(
      params.overlay.context,
      "Tilknytt aksjon",
      "Dette vil knytte apparatet til aksjonen. Vil du fortsette?",
    );
    if (!result) return dartz.left(false);
    final device = await params.bloc.attach(params.data);
    return dartz.Right(device);
  }
}

/// Edit given unit
Future<dartz.Either<bool, Device>> editDevice(
  Device device,
) =>
    EditDevice()(DeviceParams(
      device: device,
    ));

class EditDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    // The widget returned by the builder does not share a context with the location that
    // showDialog is originally called from. Provider.of will therefore fail.
    var result = await showDialog<Device>(
      context: params.overlay.context,
      builder: (context) => DeviceEditor(
        device: params.data,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);

    final device = await params.bloc.update(result);
    return dartz.Right(device);
  }
}

/// Edit last known device location
Future<dartz.Either<bool, Device>> editDeviceLocation(
  Device device,
) =>
    EditDeviceLocation()(DeviceParams(
      device: device,
    ));

class EditDeviceLocation extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    var result = await showDialog<Point>(
      context: params.overlay.context,
      builder: (context) => PointEditor(
        params.data.position,
        title: "Sett siste kjente posisjon",
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    final device = await params.bloc.update(params.data.cloneWith(position: result));
    return dartz.Right(device);
  }
}

/// Detach device from incident
Future<dartz.Either<bool, DeviceState>> detachDevice(
  BuildContext context,
  Device device,
) =>
    DetachDevice()(DeviceParams(
      device: device,
    ));

class DetachDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    var response = await prompt(
      params.overlay.context,
      "Fjern ${params.data.name}",
      "Dette vil fjerne apparatet fra sporing og aksjonen. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.update(params.data.cloneWith(status: DeviceStatus.Available));
    return dartz.Right(params.bloc.state);
  }
}

/// Delete device
Future<dartz.Either<bool, DeviceState>> deleteDevice(
  BuildContext context,
  Device device,
) =>
    DeleteDevice()(DeviceParams(
      device: device,
    ));

class DeleteDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.overlay.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne apparatet fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data);
    return dartz.Right(params.bloc.state);
  }
}
