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
import 'package:provider/provider.dart';

class DeviceParams extends BlocParams<DeviceBloc, Device> {
  DeviceParams(BuildContext context, {Device device}) : super(context, device);
}

/// Attach an device
Future<dartz.Either<bool, Device>> attachDevice(BuildContext context) => AttachDevice()(DeviceParams(context));

class AttachDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    var result = await showDialog<Device>(
      context: params.context,
      builder: (context) => DeviceEditor(
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);

    final device = await params.bloc.attach(result);
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
    var result = await showDialog<Device>(
      context: params.context,
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
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    final device = await params.bloc.update(params.data.cloneWith(point: result));
    return dartz.Right(device);
  }
}

Future<dartz.Either<bool, DeviceState>> detachDevice(
  BuildContext context,
  Device unit,
) =>
    DetachDevice()(DeviceParams(
      context,
      device: unit,
    ));

class DetachDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    var response = await prompt(
      params.context,
      "Fjern ${params.data.name}",
      "Dette vil stoppe sporing og fjerne apparatet fra hendelse. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.detach(params.data.cloneWith(status: DeviceStatus.Detached));
    return dartz.Right(params.bloc.currentState);
  }
}
