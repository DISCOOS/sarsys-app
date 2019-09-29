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

Future<dartz.Either<bool, Unit>> createUnit(UnitParams params) => CreateUnit()(params);

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

Future<dartz.Either<bool, Unit>> editUnit(UnitParams params) => EditUnit()(params);

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

Future<dartz.Either<bool, Tracking>> addToUnit(UnitParams params) => AddToUnit()(params);

class AddToUnit extends UseCase<bool, Tracking, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking>> call(params) async {
    final bloc = BlocProvider.of<TrackingBloc>(params.context);
    var unit = await selectUnit(
      params.context,
      where: (unit) => bloc.tracking[unit.tracking] == null || bloc.tracking[unit.tracking].devices.isEmpty,
    );
    if (unit == null) return dartz.Left(false);
    final state = await _handleTracking(params, unit, params.devices);
    return dartz.Right(state);
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

Future<dartz.Either<bool, UnitState>> retireUnit(UnitParams params) => RetireUnit()(params);

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
