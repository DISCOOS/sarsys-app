import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UnitParams extends BlocParams<UnitBloc, Unit> {
  final List<Device> devices;
  UnitParams(BuildContext context, {Unit unit, List<Device> devices})
      : this.devices = devices ?? const [],
        super(context, unit);
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, Unit>> createUnit(
  BuildContext context, {
  List<Device> devices,
}) =>
    CreateUnit()(UnitParams(
      context,
      devices: devices,
    ));

class CreateUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    assert(params.data == null, "Unit should not be supplied");
    var result = await showDialog<UnitEditorResult>(
      context: params.context,
      builder: (context) => UnitEditor(devices: params.devices),
    );
    if (result == null) return dartz.Left(false);

    final unit = await params.bloc.create(result.unit);
    await _handleTracking(params, unit, result.devices);
    return dartz.Right(unit);
  }
}

/// Edit given unit
Future<dartz.Either<bool, Unit>> editUnit(
  BuildContext context,
  Unit unit,
) =>
    EditUnit()(UnitParams(
      context,
      unit: unit,
    ));

class EditUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<UnitEditorResult>(
      context: params.context,
      builder: (context) => UnitEditor(unit: params.data, devices: params.devices),
    );
    if (result == null) return dartz.Left(false);

    await params.bloc.update(result.unit);
    await _handleTracking(params, result.unit, result.devices);
    return dartz.Right(result.unit);
  }
}

/// Add given devices tracking of given unit
Future<dartz.Either<bool, Tracking>> addToUnit(
  BuildContext context,
  List<Device> devices, {
  Unit unit,
}) =>
    AddToUnit()(UnitParams(
      context,
      unit: unit,
      devices: devices,
    ));

class AddToUnit extends UseCase<bool, Tracking, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking>> call(params) async {
    final bloc = BlocProvider.of<TrackingBloc>(params.context);
    var unit = params.data != null
        ? params.data
        : await selectUnit(
            params.context,
            where: (unit) => bloc.tracking[unit.tracking] == null || bloc.tracking[unit.tracking].devices.isEmpty,
          );
    if (unit == null) return dartz.Left(false);
    final state = await _handleTracking(params, unit, params.devices);
    return dartz.Right(state);
  }
}

/// Remove given devices from unit. If no devices are supplied, all devices tracked by unit is removed
Future<dartz.Either<bool, Tracking>> removeFromUnit(
  BuildContext context,
  Unit unit, {
  List<Device> devices = const [],
}) =>
    RemoveFromUnit()(UnitParams(
      context,
      unit: unit,
      devices: devices ?? [],
    ));

class RemoveFromUnit extends UseCase<bool, Tracking, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking>> call(UnitParams params) async {
    final unit = params.data;
    var proceed = await prompt(
      params.context,
      "Bekreft fjerning",
      "Dette vil fjerne ${params.devices.map((device) => device.name).join((', '))} fra ${unit.name}",
    );

    if (!proceed) return dartz.left(false);

    final bloc = BlocProvider.of<TrackingBloc>(params.context);
    final devices = params.devices.map((device) => device.id).toList();
    final tracking = await bloc.update(
      bloc.tracking[unit.tracking].cloneWith(
        devices:
            devices.isEmpty ? [] : bloc.tracking[unit.tracking].devices.where((id) => !devices.contains(id)).toList(),
      ),
    );
    return dartz.right(tracking);
  }
}

Future<Tracking> _handleTracking(UnitParams params, Unit unit, List<Device> devices) async {
  var tracking;
  final trackingBloc = BlocProvider.of<TrackingBloc>(params.context);
  if (unit.tracking == null) {
    tracking = await trackingBloc.create(unit, devices);
  } else if (trackingBloc.tracking.containsKey(unit.tracking)) {
    tracking = trackingBloc.tracking[unit.tracking];
    tracking = await trackingBloc.update(tracking, devices: devices);
  }
  return tracking;
}

Future<dartz.Either<bool, UnitState>> retireUnit(
  BuildContext context,
  Unit unit,
) =>
    RetireUnit()(UnitParams(
      context,
      unit: unit,
    ));

class RetireUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.context,
      "Oppløs ${params.data.name}",
      "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);

    await params.bloc.update(params.data.cloneWith(status: UnitStatus.Retired));
    return dartz.Right(params.bloc.currentState);
  }
}
