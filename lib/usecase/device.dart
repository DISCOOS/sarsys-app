import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/device_editor.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceParams extends BlocParams<DeviceBloc, Device> {
  DeviceParams(BuildContext context, {Device device}) : super(context, device);
}

/// Create an device
Future<dartz.Either<bool, Device>> createDevice(BuildContext context) => CreateDevice()(DeviceParams(context));

class CreateDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    var result = await showDialog<Device>(
      context: params.context,
      builder: (context) => DeviceEditor(
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);

    final device = await params.bloc.create(result);
    return dartz.Right(device);
  }
}

/// Attach an device to incident
Future<dartz.Either<bool, Device>> attachDevice(BuildContext context) => AttachDevice()(DeviceParams(context));

class AttachDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    var result = await prompt(
      params.context,
      "Tilknytt hendelse",
      "Dette vil knytte apparatet til hendelsen. Vil du fortsette?",
    );
    if (!result) return dartz.left(false);
    final device = await params.bloc.attach(params.data);
    return dartz.Right(device);
  }
}

/// Edit given unit
Future<dartz.Either<bool, Device>> editDevice(
  BuildContext context,
  Device device,
) =>
    EditDevice()(DeviceParams(
      context,
      device: device,
    ));

class EditDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    // The widget returned by the builder does not share a context with the location that
    // showDialog is originally called from. Provider.of will therefore fail.
    var result = await showDialog<Device>(
      context: params.context,
      builder: (context) => DeviceEditor(
        device: params.data,
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);

    final device = await params.bloc.update(result);
    return dartz.Right(device);
  }
}

/// Edit last known device location
Future<dartz.Either<bool, Device>> editDeviceLocation(
  BuildContext context,
  Device device,
) =>
    EditDeviceLocation()(DeviceParams(
      context,
      device: device,
    ));

class EditDeviceLocation extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    var result = await showDialog<Point>(
      context: params.context,
      builder: (context) => PointEditor(
        params.data.point,
        title: "Sett siste kjente posisjon",
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);
    final device = await params.bloc.update(params.data.cloneWith(point: result));
    return dartz.Right(device);
  }
}

/// Detach device from incident
Future<dartz.Either<bool, DeviceState>> detachDevice(
  BuildContext context,
  Device device,
) =>
    DetachDevice()(DeviceParams(
      context,
      device: device,
    ));

class DetachDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    var response = await prompt(
      params.context,
      "Fjern ${params.data.name}",
      "Dette vil fjerne apparatet fra sporing og hendelsen. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.update(params.data.cloneWith(status: DeviceStatus.Detached));
    return dartz.Right(params.bloc.currentState);
  }
}

/// Delete device
Future<dartz.Either<bool, DeviceState>> deleteDevice(
  BuildContext context,
  Device device,
) =>
    DeleteDevice()(DeviceParams(
      context,
      device: device,
    ));

class DeleteDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne apparatet fra hendelsen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data);
    return dartz.Right(params.bloc.currentState);
  }
}
