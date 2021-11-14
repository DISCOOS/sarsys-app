

import 'dart:async';

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/tracking/presentation/editors/position_editor.dart';
import 'package:SarSys/features/unit/presentation/editors/unit_editor.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/presentation/pages/units_page.dart';
import 'package:SarSys/core/domain/usecase/core.dart';
import 'package:SarSys/core/utils/ui.dart';

class UnitParams<T> extends BlocParams<UnitBloc, Unit?> {
  UnitParams({
    Unit? unit,
    this.position,
    this.devices,
    this.personnels,
    this.templates,
    UnitBloc? bloc,
  }) : super(unit, bloc: bloc);

  final Position? position;
  final List<Device>? devices;
  final List<String>? templates;
  final List<Personnel>? personnels;

  PersonnelBloc get personnelBloc => context!.read<PersonnelBloc>();
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, Unit>>? createUnit({
  Position? position,
  List<Device>? devices,
  List<Personnel>? personnels,
}) =>
    CreateUnit()(UnitParams(
      devices: devices,
      position: position,
      personnels: personnels,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class CreateUnit extends UseCase<bool, Unit?, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit?>> execute(params) async {
    assert(params.data == null, "Unit should not be supplied");
    var next = params.position;
    // Select unit position?
    if (next != null) {
      next = await (showDialog<Position>(
        context: params.overlay!.context,
        builder: (context) => PositionEditor(
          next,
          title: "Velg enhetens posisjon",
        ),
      ) as FutureOr<Position>);
      if (next == null) {
        return dartz.Left(false);
      }
    }
    var result = await showDialog<UnitParams>(
      context: params.overlay!.context,
      builder: (context) => UnitEditor(
        position: next,
        devices: params.devices,
        personnels: params.personnels,
        operation: params.context!.read<OperationBloc>().selected,
      ),
    );
    if (result == null) {
      return dartz.Left(false);
    }

    // This will create a new unit.
    //
    // Tracking will be created
    // from UnitCreated in TrackingBloc
    //
    final unit = await params.bloc.create(
      result.data,
      devices: result.devices,
      position: result.position,
    );
    return dartz.Right(unit);
  }
}

/// Create unit with tracking of given devices
Future<dartz.Either<bool, List<Unit>>>? createUnits({
  UnitBloc? bloc,
  List<String>? templates,
}) =>
    CreateUnits()(UnitParams(
      bloc: bloc,
      templates: templates,
    ))!.then((value) => value as dartz.Either<bool, List<Unit>>);

class CreateUnits extends UseCase<bool, List<Unit?>, UnitParams> {
  @override
  Future<dartz.Either<bool, List<Unit?>>> execute(UnitParams params) async {
    assert(params.templates?.isNotEmpty == true, "templates must be supplied");

    final department = params.context!.read<AffiliationBloc>().findUserDepartment();
    final units = <Unit?>[];
    int count = 0;
    params.templates!.forEach((template) async {
      final unit = params.bloc.fromTemplate(
        department!.name,
        template,
        count: ++count,
      );
      if (unit != null) {
        units.add(
          await params.bloc.create(unit),
        );
      }
    });
    return dartz.right(units);
  }
}

/// Edit given unit
Future<dartz.Either<bool, Unit>>? editUnit(
  Unit? unit,
) =>
    EditUnit()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class EditUnit extends UseCase<bool, Unit?, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit?>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");
    var result = await showDialog<UnitParams>(
      context: params.overlay!.context,
      builder: (context) => UnitEditor(
        unit: params.data,
        devices: params.devices,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Update unit - if retired tracking bloc will handle tracking
    final unit = await (params.bloc.update(result.data) as FutureOr<Unit>);

    // Only update tracking if not retired
    if (UnitStatus.retired != unit.status) {
      await params.context!.read<TrackingBloc>().replace(
            unit.tracking!.uuid,
            devices: result.devices,
            position: result.position,
            personnels: result.personnels!.map((p) => p!.uuid).toList(),
          );
    }
    return dartz.Right(result.data);
  }
}

/// Edit last known unit location
Future<dartz.Either<bool, Position>>? editUnitLocation(
  Unit unit,
) =>
    EditUnitLocation()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, Position>);

class EditUnitLocation extends UseCase<bool, Position, UnitParams> {
  @override
  Future<dartz.Either<bool, Position>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");

    final tuuid = params.data!.tracking!.uuid;
    final tracking = params.context!.read<TrackingBloc>().repo[tuuid!]!;
    assert(tracking != null, "Tracking not found: $tuuid");

    final position = await showDialog<Position>(
      context: params.overlay!.context,
      builder: (context) => PositionEditor(
        params.position,
        title: "Sett siste kjente posisjon",
      ),
    );
    if (position == null) return dartz.Left(false);

    // Update tracking with manual position
    await params.context!.read<TrackingBloc>().update(
          tracking.uuid,
          position: position,
        );

    return dartz.Right(position);
  }
}

/// Add given devices and personnel to tracking of given unit
Future<dartz.Either<bool, Unit>>? addToUnit({
  List<Device>? devices,
  List<Personnel>? personnels,
  Unit? unit,
}) =>
    AddToUnit()(UnitParams(
      unit: unit,
      devices: devices,
      personnels: personnels,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class AddToUnit extends UseCase<bool, Unit, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit>>? execute(params) async {
    // Create unit instead?
    if (!hasSelectableUnits(params, params.context!.read<TrackingBloc>())) {
      return createUnit(
        devices: params.devices,
        personnels: params.personnels,
      )!;
    }

    // Get or select unit?
    var unit = await _getOrSelectUnit(
      params,
      params.context!.read<TrackingBloc>(),
    );
    if (unit == null) return dartz.Left(false);

    // Add personnel to Unit?
    if (params.personnels?.isNotEmpty == true) {
      params.bloc.update(
        unit.copyWith(
          personnels: List.from(unit.personnels ?? [])..addAll(params.personnels!.map((p) => p!.uuid)),
        ),
      );
    }

    final tuuid = unit.tracking!.uuid;
    final tracking = params.context!.read<TrackingBloc>().repo[tuuid!]!;
    assert(tracking != null, "Tracking not found: $tuuid");

    // Add devices and personnel to unit tracking
    await params.context!.read<TrackingBloc>().attach(
          unit.tracking!.uuid,
          devices: params.devices,
          personnels: params.personnels,
        );

    return dartz.Right(unit);
  }

  Future<Unit?> _getOrSelectUnit(
    UnitParams params,
    TrackingBloc bloc,
  ) async =>
      params.data != null
          ? params.data
          : await selectUnit(
              params.overlay!.context,
              where: (unit) =>
                  // Unit is not tracking any devices or personnel?
                  _canSelectUnit(params, bloc, unit),
              // Sort units with less amount of devices on top
            );

  bool hasSelectableUnits(
    UnitParams params,
    TrackingBloc bloc,
  ) =>
      params.bloc.repo.isNotEmpty && params.bloc.repo.values.any((unit) => _canSelectUnit(params, bloc, unit!));

  bool _canSelectUnit(UnitParams params, TrackingBloc bloc, Unit unit) =>
      bloc.trackings[unit.tracking!.uuid] == null ||
      // Unit is not tracking given devices?
      !bloc.trackings[unit.tracking!.uuid]!.sources.any(
        (source) => params.devices?.any((device) => device!.uuid == source.uuid) == true,
      ) ||
      // Unit is not tracking given personnel?
      !unit.personnels.any(
        (personnel) => params.personnels?.contains(personnel) == true,
      );
}

/// Remove tracking of given devices and personnel from unit.
/// If a list is empty or null it is ignored (current list is kept)
Future<dartz.Either<bool, Tracking>>? removeFromUnit(
  Unit? unit, {
  List<Device>? devices,
  List<Personnel>? personnels,
}) =>
    RemoveFromUnit()(UnitParams(
      unit: unit,
      devices: devices,
      personnels: personnels,
    ))!.then((value) => value as dartz.Either<bool, Tracking>);

class RemoveFromUnit extends UseCase<bool, Tracking?, UnitParams> {
  @override
  Future<dartz.Either<bool, Tracking?>> execute(UnitParams params) async {
    final Unit unit = params.data!;
    final devices = params.devices ?? [];
    final personnels = params.personnels ?? [];

    // Notify intent
    final names = List.from([
      ...devices.map((device) => device!.name).toList(),
      ...personnels.map((p) => params.personnelBloc.repo[p!.uuid]?.name).toList(),
    ]).join((', '));
    var proceed = await prompt(
      params.overlay!.context,
      "Bekreft fjerning",
      "Dette vil fjerne $names fra ${unit.name}",
    );
    if (!proceed) return dartz.left(false);

    // Collect kept devices and personnel
    final keepDevices = params.context!
        .read<TrackingBloc>()
        .devices(unit.tracking!.uuid)
        .where((test) => !devices.contains(test))
        .toList();
    final keepPersonnel = unit!.personnels.where((test) => !personnels.contains(test)).toList();

    // Remove personnel from Unit?
    if (params.personnels?.isNotEmpty == true) {
      params.bloc.update(
        unit.copyWith(
          personnels: keepPersonnel,
        ),
      );
    }

    // Perform tracking update
    final tracking = await params.context!.read<TrackingBloc>().replace(
          unit.tracking!.uuid,
          devices: keepDevices,
          personnels: keepPersonnel,
        );
    return dartz.right(tracking);
  }
}

/// Transition unit to mobilized state
Future<dartz.Either<bool, Unit>>? mobilizeUnit(
  Unit? unit,
) =>
    MobilizeUnit()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class MobilizeUnit extends UseCase<bool, Unit?, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit?>> execute(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.mobilized,
    );
  }
}

/// Transition unit to deployed state
Future<dartz.Either<bool, Unit>>? deployUnit(
  Unit? unit,
) =>
    DeployUnit()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class DeployUnit extends UseCase<bool, Unit?, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit?>> execute(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.deployed,
    );
  }
}

/// Transition unit to state retired
Future<dartz.Either<bool, Unit>>? retireUnit(
  Unit? unit,
) =>
    RetireUnit()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, Unit>);

class RetireUnit extends UseCase<bool, Unit?, UnitParams> {
  @override
  Future<dartz.Either<bool, Unit?>> execute(params) async {
    return await _transitionUnit(
      params,
      UnitStatus.retired,
      action: "Oppløs ${params.data!.name}",
      message: "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
    );
  }
}

Future<dartz.Either<bool, Unit?>> _transitionUnit(UnitParams params, UnitStatus status,
    {String? action, String? message}) async {
  assert(params.data != null, "Unit must be supplied");
  if (action != null) {
    var response = await prompt(params.overlay!.context, action, message);
    if (!response) return dartz.Left(false);
  }
  final unit = await params.bloc.update(params.data!.copyWith(status: status));
  return dartz.Right(unit);
}

/// Delete unit
Future<dartz.Either<bool, UnitState>>? deleteUnit(
  Unit? unit,
) =>
    DeleteUnit()(UnitParams(
      unit: unit,
    ))!.then((value) => value as dartz.Either<bool, UnitState<dynamic>>);

class DeleteUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> execute(params) async {
    assert(params.data != null, "Unit must be supplied");
    var response = await prompt(
      params.overlay!.context,
      "Slett ${params.data!.name}",
      "Dette vil slette alle data fra sporinger og fjerne enheten fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data!.uuid);
    return dartz.Right(params.bloc.state);
  }
}
