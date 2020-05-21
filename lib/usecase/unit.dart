import 'package:SarSys/core/streams.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/position_editor.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/ui_utils.dart';

class UnitParams<T> extends BlocParams<UnitBloc, Unit> {
  final Position position;
  final List<Device> devices;
  final List<Personnel> personnels;

  UnitParams({
    Unit unit,
    this.position,
    this.devices,
    this.personnels,
  }) : super(unit);
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, Unit>> createUnit({
  Position position,
  List<Device> devices,
  List<Personnel> personnel,
}) =>
    CreateUnit()(UnitParams(
      devices: devices,
      position: position,
      personnels: personnel,
    ));

class CreateUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> execute(params) async {
    assert(params.data == null, "Unit should not be supplied");
    var next = params.position;
    // Select unit position?
    if (next != null) {
      next = await showDialog<Position>(
        context: params.overlay.context,
        builder: (context) => PositionEditor(
          next,
          title: "Velg enhetens posisjon",
          controller: params.controller,
        ),
      );
      if (next == null) return dartz.Left(false);
    }
    var result = await showDialog<UnitParams>(
      context: params.overlay.context,
      builder: (context) => UnitEditor(
        position: next,
        devices: params.devices,
        personnels: params.personnels,
        controller: params.controller,
      ),
    );
    if (result == null) return dartz.Left(false);

    // This will create unit and tracking
    final unit = await params.bloc.create(result.data);

    // Wait for tracking is created
    final tracking = await waitThroughStateWithData<TrackingCreated, Tracking>(
      params.context.bloc<TrackingBloc>(),
      map: (state) => state.data,
      test: (state) => state.data.uuid == unit.tracking.uuid,
    );

    // Update tracking
    await params.context.bloc<TrackingBloc>().replace(
          tracking.uuid,
          devices: result.devices,
          position: result.position,
          personnels: result.personnels,
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
  Future<dartz.Either<bool, Unit>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<UnitParams>(
      context: params.overlay.context,
      builder: (context) => UnitEditor(
        unit: params.data,
        devices: params.devices,
        controller: params.controller,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Update unit - if retired tracking bloc will handle tracking
    final unit = await params.bloc.update(result.data);

    // Only update tracking if not retired
    if (UnitStatus.Retired != unit.status) {
      await params.context.bloc<TrackingBloc>().replace(
            unit.tracking.uuid,
            devices: result.devices,
            position: result.position,
            personnels: result.personnels,
          );
    }
    return dartz.Right(result.data);
  }
}

/// Edit last known unit location
Future<dartz.Either<bool, Position>> editUnitLocation(
  Unit unit,
) =>
    EditUnitLocation()(UnitParams(
      unit: unit,
    ));

class EditUnitLocation extends UseCase<bool, Position, UnitParams> {
  @override
  Future<dartz.Either<bool, Position>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");

    final tuuid = params.data.tracking.uuid;
    final tracking = params.context.bloc<TrackingBloc>().repo[tuuid];
    assert(tracking != null, "Tracking not found: $tuuid");

    final position = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.position,
        title: "Sett siste kjente posisjon",
        controller: params.controller,
      ),
    );
    if (position == null) return dartz.Left(false);

    // Update tracking with manual position
    await params.context.bloc<TrackingBloc>().update(
          tracking.uuid,
          position: position,
        );

    return dartz.Right(position);
  }
}

/// Add given devices and personnel to tracking of given unit
Future<dartz.Either<bool, Unit>> addToUnit({
  List<Device> devices,
  List<Personnel> personnel,
  Unit unit,
}) =>
    AddToUnit()(UnitParams(
      unit: unit,
      devices: devices,
      personnels: personnel,
    ));

class AddToUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> execute(params) async {
    // Create unit instead?
    if (!hasSelectableUnits(params, params.context.bloc<TrackingBloc>())) {
      return createUnit(
        devices: params.devices,
        personnel: params.personnels,
      );
    }

    // Get or select unit?
    var unit = await _getOrSelectUnit(
      params,
      params.context.bloc<TrackingBloc>(),
    );
    if (unit == null) return dartz.Left(false);

    // Add personnel to Unit?
    if (params.personnels?.isNotEmpty == true) {
      params.bloc.update(
        unit.cloneWith(
          personnels: List.from(unit.personnels ?? [])..addAll(params.personnels),
        ),
      );
    }

    final tuuid = unit.tracking.uuid;
    final tracking = params.context.bloc<TrackingBloc>().repo[tuuid];
    assert(tracking != null, "Tracking not found: $tuuid");

    // Add devices and personnel to unit tracking
    await params.context.bloc<TrackingBloc>().attach(
          unit.tracking.uuid,
          devices: params.devices,
          personnels: params.personnels,
        );

    return dartz.Right(unit);
  }

  Future<Unit> _getOrSelectUnit(
    UnitParams params,
    TrackingBloc bloc,
  ) async =>
      params.data != null
          ? params.data
          : await selectUnit(
              params.overlay.context,
              where: (unit) =>
                  // Unit is not tracking any devices or personnel?
                  _canSelectUnit(params, bloc, unit),
              // Sort units with less amount of devices on top
            );

  bool hasSelectableUnits(
    UnitParams params,
    TrackingBloc bloc,
  ) =>
      params.bloc.repo.isNotEmpty && params.bloc.repo.values.any((unit) => _canSelectUnit(params, bloc, unit));

  bool _canSelectUnit(UnitParams params, TrackingBloc bloc, Unit unit) =>
      bloc.trackings[unit.tracking.uuid] == null ||
      // Unit is not tracking given devices?
      !bloc.trackings[unit.tracking.uuid].sources.any(
        (source) => params.devices?.any((device) => device.uuid == source.uuid) == true,
      ) ||
      // Unit is not tracking given personnel?
      !unit.personnels.any(
        (personnel) => params.personnels?.contains(personnel) == true,
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
      personnels: personnel,
    ));

class RemoveFromUnit extends UseCase<bool, Tracking, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking>> execute(UnitParams params) async {
    final unit = params.data;
    final devices = params.devices ?? [];
    final personnel = params.personnels ?? [];

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
    final keepPersonnel = unit.personnels.where((test) => !personnel.contains(test)).toList();

    // Remove personnel from Unit?
    if (params.personnels?.isNotEmpty == true) {
      params.bloc.update(
        unit.cloneWith(
          personnels: keepPersonnel,
        ),
      );
    }

    // Perform tracking update
    final tracking = await params.context.bloc<TrackingBloc>().replace(
          unit.tracking.uuid,
          devices: keepDevices,
          personnels: keepPersonnel,
        );
    return dartz.right(tracking);
  }
}

//Future<Tracking> _handleTracking(
//  UnitParams params,
//  Unit unit, {
//  @required bool replace,
//  List<Device> devices,
//  List<Personnel> personnel,
//  Position position,
//}) async {
//  final tracking = await waitThoughtState<TrackingCreated, Tracking>(
//    params.bloc,
//    test: (state) => state.data.uuid == unit.tracking.uuid,
//    map: (state) => state.data,
//  );
//  return await params.context.bloc<TrackingBloc>().update(
//        tracking,
//        position: position,
//        devices: devices,
//        personnel: personnel,
//        replace: replace,
//      );
//}

/// Transition unit to mobilized state
Future<dartz.Either<bool, Unit>> mobilizeUnit(
  Unit unit,
) =>
    MobilizeUnit()(UnitParams(
      unit: unit,
    ));

class MobilizeUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>> execute(params) async {
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
  Future<dartz.Either<bool, Unit>> execute(params) async {
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
  Future<dartz.Either<bool, Unit>> execute(params) async {
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
  Future<dartz.Either<bool, UnitState>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.overlay.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne enheten fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data.uuid);
    return dartz.Right(params.bloc.state);
  }
}
