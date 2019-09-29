import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
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

Future<dartz.Either<bool, UnitState>> createUnit(UnitParams params) => CreateUnit()(params);

class CreateUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    var result = await showDialog<UnitEditorResult>(
      context: params.context,
      builder: (context) => UnitEditor(devices: params.devices),
    );
    if (result == null) return dartz.Left(false);

    final unit = await params.bloc.create(result.unit);
    await _handleTracking(params, unit, result.devices);
    return dartz.Right(params.bloc.currentState);
  }
}

Future<dartz.Either<bool, UnitState>> editUnit(UnitParams params) => EditUnit()(params);

class EditUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    var result = await showDialog<UnitEditorResult>(
      context: params.context,
      builder: (context) => UnitEditor(unit: params.data, devices: params.devices),
    );
    if (result == null) return dartz.Left(false);

    await params.bloc.update(result.unit);
    await _handleTracking(params, result.unit, result.devices);
    return dartz.Right(params.bloc.currentState);
  }
}

Future<dartz.Either<bool, TrackingState>> addToUnit(UnitParams params) => AddToUnit()(params);

class AddToUnit extends UseCase<bool, TrackingState, UnitParams> {
  @override
  Future<dartz.Either<bool, TrackingState>> call(params) async {
    var unit = await selectUnit(params.context);
    if (unit == null) return dartz.Left(false);
    final state = await _handleTracking(params, unit, params.devices);
    return dartz.Right(state);
  }
}

Future<TrackingState> _handleTracking(UnitParams params, Unit unit, List<Device> devices) async {
  final trackingBloc = BlocProvider.of<TrackingBloc>(params.context);
  if (unit.tracking == null) {
    await trackingBloc.create(unit, devices);
  } else if (trackingBloc.tracks.containsKey(unit.tracking)) {
    var tracking = trackingBloc.tracks[unit.tracking];
    await trackingBloc.update(tracking, devices: devices);
  }
  return trackingBloc.currentState;
}

Future<dartz.Either<bool, UnitState>> retireUnit(UnitParams params) => RetireUnit()(params);

class RetireUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
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
