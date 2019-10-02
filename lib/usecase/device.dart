import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';

class DeviceParams extends BlocParams<DeviceBloc, Device> {
  DeviceParams(BuildContext context, {Device device}) : super(context, device);
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, Device>> createDevice(BuildContext context) => CreateDevice()(DeviceParams(context));

class CreateDevice extends UseCase<bool, Device, DeviceParams> {
  @override
  Future<dartz.Either<bool, Device>> call(params) async {
    assert(params.data == null, "Device should not be supplied");
    return dartz.Left(false);
//    var result = await showDialog<DeviceEditorResult>(
//      context: params.context,
//      builder: (context) => DeviceEditor(devices: params.devices),
//    );
//    if (result == null) return dartz.Left(false);
//
//    final unit = await params.bloc.create(result.unit);
//    await _handleTracking(params, unit, result.devices);
//    return dartz.Right(unit);
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
    return dartz.Left(false);
//    var result = await showDialog<DeviceEditorResult>(
//      context: params.context,
//      builder: (context) => DeviceEditor(unit: params.data, devices: params.devices),
//    );
//    if (result == null) return dartz.Left(false);
//
//    await params.bloc.update(result.unit);
//    await _handleTracking(params, result.unit, result.devices);
//    return dartz.Right(result.unit);
  }
}

Future<dartz.Either<bool, DeviceState>> retireDevice(
  BuildContext context,
  Device unit,
) =>
    RetireDevice()(DeviceParams(
      context,
      device: unit,
    ));

class RetireDevice extends UseCase<bool, DeviceState, DeviceParams> {
  @override
  Future<dartz.Either<bool, DeviceState>> call(params) async {
    assert(params.data != null, "Device must be supplied");
    return dartz.Left(false);
//    var response = await prompt(
//      params.context,
//      "Oppløs ${params.data.name}",
//      "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
//    );
//    if (!response) return dartz.Left(false);
//
//    await params.bloc.update(params.data.cloneWith(status: DeviceStatus.Retired));
//    return dartz.Right(params.bloc.currentState);
  }
}
