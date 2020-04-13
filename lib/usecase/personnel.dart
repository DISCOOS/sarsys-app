import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/editors/personnel_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/pages/personnel_page.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class PersonnelParams extends BlocParams<PersonnelBloc, Personnel> {
  final Point point;
  final List<Device> devices;
  PersonnelParams(
    BuildContext context, {
    Personnel personnel,
    this.point,
    this.devices,
  }) : super(context, personnel);
}

/// Create personnel with tracking of given devices
Future<dartz.Either<bool, Personnel>> createPersonnel(
  BuildContext context, {
  List<Device> devices,
}) =>
    CreatePersonnel()(PersonnelParams(
      context,
      devices: devices,
    ));

class CreatePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> call(params) async {
    assert(params.data == null, "Personnel should not be supplied");
    var result = await showDialog<PersonnelParams>(
      context: params.context,
      builder: (context) => PersonnelEditor(
        devices: params.devices,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);

    final personnel = await params.bloc.create(result.data);
    await _handleTracking(params, personnel, devices: result.devices, point: result.point);
    return dartz.Right(personnel);
  }
}

/// Edit given personnel
Future<dartz.Either<bool, Personnel>> editPersonnel(
  BuildContext context,
  Personnel personnel,
) =>
    EditPersonnel()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class EditPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> call(params) async {
    assert(params.data != null, "Personnel must be supplied");
    var result = await showDialog<PersonnelParams>(
      context: params.context,
      builder: (context) => PersonnelEditor(
        personnel: params.data,
        devices: params.devices,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(result.data);
    await _handleTracking(
      params,
      result.data,
      devices: result.devices,
      point: result.point,
      append: false,
    );
    return dartz.Right(result.data);
  }
}

/// Edit last known personnel location
Future<dartz.Either<bool, Point>> editPersonnelLocation(
  BuildContext context,
  Personnel personnel,
) =>
    EditPersonnelLocation()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class EditPersonnelLocation extends UseCase<bool, Point, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.data != null, "Personnel must be supplied");
    var result = await showDialog<Point>(
      context: params.context,
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

/// Add given devices tracking of given personnel
Future<dartz.Either<bool, Pair<Personnel, Tracking>>> addToPersonnel(
  BuildContext context,
  List<Device> devices, {
  Personnel personnel,
}) =>
    AddToPersonnel()(PersonnelParams(
      context,
      personnel: personnel,
      devices: devices,
    ));

class AddToPersonnel extends UseCase<bool, Pair<Personnel, Tracking>, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Pair<Personnel, Tracking>>> call(params) async {
    final bloc = BlocProvider.of<TrackingBloc>(params.context);
    var personnel = params.data != null
        ? params.data
        : await selectPersonnel(
            params.context,
            where: (personnel) =>
                // Personnel is not tracking any devices?
                bloc.tracking[personnel.tracking] == null ||
                // Personnel is not tracking given devices?
                !bloc.tracking[personnel.tracking].devices.any(
                  (device) => params.devices?.contains(device) == true,
                ),
          );
    if (personnel == null) return dartz.Left(false);
    final tracking = await _handleTracking(
      params,
      personnel,
      devices: params.devices,
      append: true,
    );
    return dartz.Right(Pair.of(personnel, tracking));
  }
}

/// Remove given devices from personnel. If no devices are supplied, all devices tracked by personnel is removed
Future<dartz.Either<bool, Tracking>> removeFromPersonnel(
  BuildContext context,
  Personnel personnel, {
  List<Device> devices,
}) =>
    RemoveFromPersonnel()(PersonnelParams(
      context,
      personnel: personnel,
      devices: devices,
    ));

class RemoveFromPersonnel extends UseCase<bool, Tracking, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Tracking>> call(PersonnelParams params) async {
    final personnel = params.data;
    final devices = params.devices ?? [];

    // Notify intent
    var proceed = await prompt(
      params.context,
      "Bekreft fjerning",
      "Dette vil fjerne ${devices.map((device) => device.name).join((', '))} fra ${personnel.name}",
    );
    if (!proceed) return dartz.left(false);

    // Prepare removal
    final bloc = BlocProvider.of<TrackingBloc>(params.context);

    // Collect kept devices and personnel
    final keepDevices = bloc.devices(personnel.tracking).where((test) => !devices.contains(test)).toList();

    final tracking = await bloc.update(
      bloc.tracking[personnel.tracking],
      devices: keepDevices,
      append: false,
    );
    return dartz.right(tracking);
  }
}

// TODO: Move to tracking service and convert to internal TrackingMessage
Future<Tracking> _handleTracking(
  PersonnelParams params,
  Personnel personnel, {
  List<Device> devices,
  Point point,
  bool append,
}) async {
  Tracking tracking;
  final trackingBloc = BlocProvider.of<TrackingBloc>(params.context);
  if (personnel.tracking == null) {
    tracking = await trackingBloc.trackPersonnel(
      personnel,
      devices: devices,
    );
  } else if (trackingBloc.tracking.containsKey(personnel.tracking)) {
    tracking = trackingBloc.tracking[personnel.tracking];
    tracking = await trackingBloc.update(
      tracking,
      point: point,
      devices: devices,
      append: append,
    );
  }
  return tracking;
}

/// Transition personnel to mobilized state
Future<dartz.Either<bool, Personnel>> mobilizePersonnel(
  BuildContext context,
  Personnel personnel,
) =>
    MobilizePersonnel()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class MobilizePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> call(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.Mobilized,
    );
  }
}

Future<dartz.Either<bool, Personnel>> checkInPersonnel(
  BuildContext context,
  Personnel personnel,
) =>
    DeployPersonnel()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class DeployPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> call(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.OnScene,
    );
  }
}

/// Transition personnel to retired state
Future<dartz.Either<bool, Personnel>> retirePersonnel(
  BuildContext context,
  Personnel personnel,
) =>
    RetirePersonnel()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class RetirePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> call(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.Retired,
      action: "Dimittere ${params.data.name}",
      message: "Dette vil stoppe sporing og dimmitere mannskapet. Vil du fortsette?",
    );
  }
}

Future<dartz.Either<bool, Personnel>> _transitionPersonnel(PersonnelParams params, PersonnelStatus status,
    {String action, String message}) async {
  assert(params.data != null, "Personnel must be supplied");
  if (action != null) {
    var response = await prompt(params.context, action, message);
    if (!response) return dartz.Left(false);
  }
  final personnel = await params.bloc.update(params.data.cloneWith(status: status));
  return dartz.Right(personnel);
}

/// Delete personnel
Future<dartz.Either<bool, PersonnelState>> deletePersonnel(
  BuildContext context,
  Personnel personnel,
) =>
    DeletePersonnel()(PersonnelParams(
      context,
      personnel: personnel,
    ));

class DeletePersonnel extends UseCase<bool, PersonnelState, PersonnelParams> {
  @override
  Future<dartz.Either<bool, PersonnelState>> call(params) async {
    assert(params.data != null, "Personnel must be supplied");
    var response = await prompt(
      params.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne mannskapet fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data);
    return dartz.Right(params.bloc.currentState);
  }
}
