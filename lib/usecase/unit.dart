import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class UnitParams<T> extends BlocParams<UnitBloc, Unit> {
  final Point point;
  final List<Device> devices;
  final List<Personnel> personnel;

  UnitParams({
    Unit unit,
    this.point,
    this.devices,
    this.personnel,
  }) : super(unit);
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, Unit>> createUnit({
  Point point,
  List<Device> devices,
  List<Personnel> personnel,
}) =>
    CreateUnit()(UnitParams(
      point: point,
      devices: devices,
      personnel: personnel,
    ));

class CreateUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    assert(params.data == null, "Unit should not be supplied");
    var point = params.point;
    // Select unit position?
    if (point != null) {
      point = await showDialog<Point>(
        context: params.overlay.context,
        builder: (context) => PointEditor(
          point,
          title: "Velg enhetens posisjon",
          controller: Provider.of<PermissionController>(params.context),
        ),
      );
      if (point == null) return dartz.Left(false);
    }
    var result = await showDialog<UnitParams>(
      context: params.overlay.context,
      builder: (context) => UnitEditor(
        point: point,
        devices: params.devices,
        personnel: params.personnel,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);

    final unit = await params.bloc.create(result.data);
    await _handleTracking(
      params,
      unit,
      point: result.point,
      devices: result.devices,
      personnel: result.personnel,
    );
    return dartz.Right(unit);
  }
}

/// Edit given unit
Future<dartz.Either<bool, Unit>> editUnit(
  Unit unit,
) =>
    EditUnit()(UnitParams(
      unit: unit,
    ));

class EditUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<UnitParams>(
      context: params.overlay.context,
      builder: (context) => UnitEditor(
        unit: params.data,
        devices: params.devices,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(result.data);
    await _handleTracking(
      params,
      result.data,
      point: result.point,
      devices: result.devices,
      personnel: result.personnel,
      append: false,
    );
    return dartz.Right(result.data);
  }
}

/// Edit last known unit location
Future<dartz.Either<bool, Point>> editUnitLocation(
  Unit unit,
) =>
    EditUnitLocation()(UnitParams(
      unit: unit,
    ));

class EditUnitLocation extends UseCase<bool, Point, UnitParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<Point>(
      context: params.overlay.context,
      builder: (context) => PointEditor(
        params.point,
        title: "Sett siste kjente posisjon",
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    await _handleTracking(params, params.data, point: result);
    return dartz.Right(result);
  }
}

/// Add given devices and personnel to tracking of given unit
Future<dartz.Either<bool, Pair<Unit, Tracking>>> addToUnit({
  List<Device> devices,
  List<Personnel> personnel,
  Unit unit,
}) =>
    AddToUnit()(UnitParams(
      unit: unit,
      devices: devices,
      personnel: personnel,
    ));

class AddToUnit extends UseCase<bool, Pair<Unit, Tracking>, UnitParams> {
  @override
  Future<dartz.Either<bool, Pair<Unit, Tracking>>> call(params) async {
    final bloc = BlocProvider.of<TrackingBloc>(params.context);

    // Get or select unit?
    var unit = await _toUnit(params, bloc);
    if (unit == null) return dartz.Left(false);

    // Add personnel to Unit?
    if (params.personnel?.isNotEmpty == true) {
      params.bloc.update(
        unit.cloneWith(
          personnel: List.from(unit.personnel ?? [])..addAll(params.personnel),
        ),
      );
    }

    // Update tracking
    final tracking = await _handleTracking(
      params,
      unit,
      devices: params.devices,
      personnel: params.personnel,
      append: true,
    );
    return dartz.Right(Pair.of(unit, tracking));
  }

  Future<Unit> _toUnit(
    UnitParams params,
    TrackingBloc bloc,
  ) async =>
      params.data != null
          ? params.data
          : await selectUnit(
              params.overlay.context,
              where: (unit) =>
                  // Unit is not tracking any devices or personnel?
                  bloc.tracking[unit.tracking.uuid] == null ||
                  // Unit is not tracking given devices?
                  !bloc.tracking[unit.tracking.uuid].devices.any(
                    (device) => params.devices?.contains(device) == true,
                  ) ||
                  // Unit is not tracking given personnel?
                  !unit.personnel.any(
                    (personnel) => params.personnel?.contains(personnel) == true,
                  ),
              // Sort units with less amount of devices on top
            );
}

/// Remove tracking of given devices and personnel from unit.
/// If a list is empty or null it is ignored (current list is kept)
Future<dartz.Either<bool, Tracking>> removeFromUnit(
  Unit unit, {
  List<Device> devices,
  List<Personnel> personnel,
}) =>
    RemoveFromUnit()(UnitParams(
      unit: unit,
      devices: devices,
      personnel: personnel,
    ));

class RemoveFromUnit extends UseCase<bool, Tracking, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking>> call(UnitParams params) async {
    final unit = params.data;
    final devices = params.devices ?? [];
    final personnel = params.personnel ?? [];

    // Notify intent
    final names = List.from([
      ...devices.map((device) => device.name).toList(),
      ...personnel.map((personnel) => personnel.name).toList(),
    ]).join((', '));
    var proceed = await prompt(
      params.overlay.context,
      "Bekreft fjerning",
      "Dette vil fjerne $names fra ${unit.name}",
    );
    if (!proceed) return dartz.left(false);

    // Collect kept devices and personnel
    final keepDevices = params.context
        .bloc<TrackingBloc>()
        .devices(unit.tracking.uuid)
        .where((test) => !devices.contains(test))
        .toList();
    final keepPersonnel = unit.personnel.where((test) => !personnel.contains(test)).toList();

    // Remove personnel from Unit?
    if (params.personnel?.isNotEmpty == true) {
      params.bloc.update(
        unit.cloneWith(
          personnel: keepPersonnel,
        ),
      );
    }

    // Perform tracking update
    final tracking = await params.context.bloc<TrackingBloc>().update(
          params.context.bloc<TrackingBloc>().tracking[unit.tracking.uuid],
          devices: keepDevices,
          personnel: keepPersonnel,
          append: false,
        );
    return dartz.right(tracking);
  }
}

// TODO: Move to tracking service and convert to internal TrackingMessage
Future<Tracking> _handleTracking(
  UnitParams params,
  Unit unit, {
  List<Device> devices,
  List<Personnel> personnel,
  Point point,
  bool append,
}) async {
  Tracking tracking;
  final items = params.context.bloc<TrackingBloc>().tracking;
  if (unit.tracking == null) {
    tracking = await params.context.bloc<TrackingBloc>().trackUnit(
          unit,
          point: point,
          devices: devices,
          personnel: personnel,
        );
  } else if (items.containsKey(unit.tracking.uuid)) {
    tracking = items[unit.tracking.uuid];
    tracking = await params.context.bloc<TrackingBloc>().update(
          tracking,
          point: point,
          devices: devices,
          personnel: personnel,
          append: append,
        );
  }
  return tracking;
}

/// Transition unit to mobilized state
Future<dartz.Either<bool, Unit>> mobilizeUnit(
  Unit unit,
) =>
    MobilizeUnit()(UnitParams(
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
  Unit unit,
) =>
    DeployUnit()(UnitParams(
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
  Unit unit,
) =>
    RetireUnit()(UnitParams(
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
    var response = await prompt(params.overlay.context, action, message);
    if (!response) return dartz.Left(false);
  }
  final unit = await params.bloc.update(params.data.cloneWith(status: status));
  return dartz.Right(unit);
}

/// Delete unit
Future<dartz.Either<bool, UnitState>> deleteUnit(
  Unit unit,
) =>
    DeleteUnit()(UnitParams(
      unit: unit,
    ));

class DeleteUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.overlay.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne enheten fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data);
    return dartz.Right(params.bloc.state);
  }
}
