import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UnitParams extends BlocParams<UnitBloc, Unit> {
  final Point point;
  final List<Device> devices;

  UnitParams(
    BuildContext context, {
    Unit unit,
    List<Device> devices,
    this.point,
  })  : this.devices = devices ?? const [],
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
    var result = await showDialog<UnitParams>(
      context: params.context,
      builder: (context) => UnitEditor(
        devices: params.devices,
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);

    final unit = await params.bloc.create(result.data);
    await _handleTracking(params, unit, devices: result.devices, point: result.point);
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
    var result = await showDialog<UnitParams>(
      context: params.context,
      builder: (context) => UnitEditor(
        unit: params.data,
        devices: params.devices,
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(result.data);
    await _handleTracking(params, result.data, devices: result.devices, point: result.point);
    return dartz.Right(result.data);
  }
}

/// Edit last known unit location
Future<dartz.Either<bool, Point>> editUnitLocation(
  BuildContext context,
  Unit unit,
) =>
    EditUnitLocation()(UnitParams(
      context,
      unit: unit,
    ));

class EditUnitLocation extends UseCase<bool, Point, UnitParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<Point>(
      context: params.context,
      builder: (context) => PointEditor(
        params.point,
        title: "Sett siste kjente posisjon",
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);
    await _handleTracking(params, params.data, point: result);
    return dartz.Right(result);
  }
}

/// Add given devices tracking of given unit
Future<dartz.Either<bool, Pair<Unit, Tracking>>> addToUnit(
  BuildContext context,
  List<Device> devices, {
  Unit unit,
}) =>
    AddToUnit()(UnitParams(
      context,
      unit: unit,
      devices: devices,
    ));

class AddToUnit extends UseCase<bool, Pair<Unit, Tracking>, UnitParams> {
  @override
  Future<dartz.Either<bool, Pair<Unit, Tracking>>> call(params) async {
    final bloc = BlocProvider.of<TrackingBloc>(params.context);
    var unit = params.data != null
        ? params.data
        : await selectUnit(
            params.context,
            where: (unit) =>
                // Unit is not tracking any devices or personnel?
                bloc.tracking[unit.tracking] == null ||
                // Unit is not tracking given devices?
                bloc.tracking[unit.tracking].devices.any((device) => params.devices.contains(device)) == false,
            // Sort units with less amount of devices on top
          );
    if (unit == null) return dartz.Left(false);
    final tracking = await _handleTracking(params, unit, devices: params.devices);
    return dartz.Right(Pair.of(unit, tracking));
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

// TODO: Move to tracking service and convert to internal TrackingMessage
Future<Tracking> _handleTracking(
  UnitParams params,
  Unit unit, {
  List<Device> devices,
  Point point,
}) async {
  Tracking tracking;
  final trackingBloc = BlocProvider.of<TrackingBloc>(params.context);
  if (unit.tracking == null) {
    tracking = await trackingBloc.trackUnit(unit, devices);
  } else if (trackingBloc.tracking.containsKey(unit.tracking)) {
    tracking = trackingBloc.tracking[unit.tracking];
    tracking = await trackingBloc.update(tracking, devices: devices, point: point);
  }
  return tracking;
}

/// Transition unit to mobilized state
Future<dartz.Either<bool, Unit>> mobilizeUnit(
  BuildContext context,
  Unit unit,
) =>
    MobilizeUnit()(UnitParams(
      context,
      unit: unit,
    ));

class MobilizeUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.Mobilized,
    );
  }
}

/// Transition unit to deployed state
Future<dartz.Either<bool, Unit>> deployUnit(
  BuildContext context,
  Unit unit,
) =>
    DeployUnit()(UnitParams(
      context,
      unit: unit,
    ));

class DeployUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.Deployed,
    );
  }
}

/// Transition unit to state Retired
Future<dartz.Either<bool, Unit>> retireUnit(
  BuildContext context,
  Unit unit,
) =>
    RetireUnit()(UnitParams(
      context,
      unit: unit,
    ));

class RetireUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.Retired,
      action: "Oppløs ${params.data.name}",
      message: "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
    );
  }
}

Future<dartz.Either<bool, Unit>> _transitionUnit(UnitParams params, UnitStatus status,
    {String action, String message}) async {
  assert(params.data != null, "Unit must be supplied");
  if (action != null) {
    var response = await prompt(params.context, action, message);
    if (!response) return dartz.Left(false);
  }
  final unit = await params.bloc.update(params.data.cloneWith(status: status));
  return dartz.Right(unit);
}

/// Delete unit
Future<dartz.Either<bool, UnitState>> deleteUnit(
  BuildContext context,
  Unit unit,
) =>
    DeleteUnit()(UnitParams(
      context,
      unit: unit,
    ));

class DeleteUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne enheten fra hendelsen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data);
    return dartz.Right(params.bloc.currentState);
  }
}
