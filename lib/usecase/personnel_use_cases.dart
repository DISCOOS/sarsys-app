import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/streams.dart';
import 'package:SarSys/editors/position_editor.dart';
import 'package:SarSys/editors/personnel_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/pages/personnel_page.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:catcher/core/catcher.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/extensions.dart';
import 'package:uuid/uuid.dart';

class PersonnelParams extends BlocParams<PersonnelBloc, Personnel> {
  final Position position;
  final List<Device> devices;
  IncidentBloc get incidentBloc => bloc.incidentBloc;
  User get user => incidentBloc.userBloc.user;
  PersonnelParams({
    Personnel personnel,
    this.position,
    this.devices,
    PersonnelBloc bloc,
  }) : super(personnel, bloc: bloc);
}

/// Create personnel with tracking of given devices
Future<dartz.Either<bool, Personnel>> createPersonnel({
  List<Device> devices,
}) =>
    CreatePersonnel()(PersonnelParams(
      devices: devices,
    ));

class CreatePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data == null, "Personnel should not be supplied");
    var result = await showDialog<PersonnelParams>(
      context: params.overlay.context,
      builder: (context) => PersonnelEditor(
        devices: params.devices,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Will create personnel and tracking
    final personnel = await params.bloc.create(result.data);

    // TODO: Move to use case replaceTracking
    // Wait for tracking is created
    final tracking = await waitThroughStateWithData<TrackingCreated, Tracking>(
      params.context.bloc<TrackingBloc>(),
      map: (state) => state.data,
      test: (state) => state.data.uuid == personnel.tracking.uuid,
    );

    // Update tracking
    await params.context.bloc<TrackingBloc>().replace(
          tracking.uuid,
          devices: result.devices,
          position: result.position,
        );
    return dartz.Right(personnel);
  }
}

/// Edit given personnel
Future<dartz.Either<bool, Personnel>> editPersonnel(
  Personnel personnel,
) =>
    EditPersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class EditPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data != null, "Personnel must be supplied");
    var result = await showDialog<PersonnelParams>(
      context: params.overlay.context,
      builder: (context) => PersonnelEditor(
        personnel: params.data,
        devices: params.devices,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Update personnel - if retired tracking bloc will handle tracking
    final personnel = await params.bloc.update(result.data);

    // Only update tracking if not retired
    if (PersonnelStatus.Retired != personnel.status) {
      await params.context.bloc<TrackingBloc>().replace(
            personnel.tracking.uuid,
            devices: result.devices,
            position: result.position,
          );
    }
    return dartz.Right(result.data);
  }
}

/// Edit last known personnel location
Future<dartz.Either<bool, Position>> editPersonnelLocation(
  Personnel personnel,
) =>
    EditPersonnelLocation()(PersonnelParams(
      personnel: personnel,
    ));

class EditPersonnelLocation extends UseCase<bool, Position, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Position>> execute(params) async {
    assert(params.data != null, "Personnel must be supplied");

    final tuuid = params.data.tracking.uuid;
    final tracking = params.context.bloc<TrackingBloc>().repo[tuuid];
    assert(tracking != null, "Tracking not found: $tuuid");

    var position = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.position,
        title: "Sett siste kjente posisjon",
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

/// Add given devices tracking of given personnel
Future<dartz.Either<bool, Pair<Personnel, Tracking>>> addToPersonnel(
  List<Device> devices, {
  Personnel personnel,
}) =>
    AddToPersonnel()(PersonnelParams(
      personnel: personnel,
      devices: devices,
    ));

class AddToPersonnel extends UseCase<bool, Pair<Personnel, Tracking>, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Pair<Personnel, Tracking>>> execute(params) async {
    // Get or select unit?
    Personnel personnel = await _getOrSelectPersonnel(
      params,
      params.context.bloc<TrackingBloc>(),
    );
    if (personnel == null) return dartz.Left(false);

    final tuuid = personnel.tracking.uuid;
    final tracking = params.context.bloc<TrackingBloc>().repo[tuuid];
    assert(tracking != null, "Tracking not found: $tuuid");

    // Add to tracking
    final next = await params.context.bloc<TrackingBloc>().attach(
          personnel.tracking.uuid,
          devices: params.devices,
        );
    return dartz.Right(Pair.of(personnel, next));
  }

  Future<Personnel> _getOrSelectPersonnel(PersonnelParams params, TrackingBloc bloc) async {
    var personnel = params.data != null
        ? params.data
        : await selectPersonnel(
            params.overlay.context,
            where: (personnel) =>
                // Personnel is not tracking any devices?
                bloc.trackings[personnel.tracking.uuid] == null ||
                // Personnel is not tracking given devices?
                !bloc.trackings[personnel.tracking.uuid].sources.any(
                  (source) => params.devices?.any((device) => device.uuid == source.uuid) == true,
                ),
          );
    return personnel;
  }
}

/// Remove given devices from personnel. If no devices are supplied, all devices tracked by personnel is removed
Future<dartz.Either<bool, Tracking>> removeFromPersonnel(
  Personnel personnel, {
  List<Device> devices,
}) =>
    RemoveFromPersonnel()(PersonnelParams(
      personnel: personnel,
      devices: devices,
    ));

class RemoveFromPersonnel extends UseCase<bool, Tracking, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Tracking>> execute(PersonnelParams params) async {
    final personnel = params.data;
    final devices = params.devices ?? [];

    // Notify intent
    var proceed = await prompt(
      params.overlay.context,
      "Bekreft fjerning",
      "Dette vil fjerne ${devices.map((device) => device.name).join((', '))} fra ${personnel.name}",
    );
    if (!proceed) return dartz.left(false);

    // Collect kept devices and personnel
    final keepDevices = params.context
        .bloc<TrackingBloc>()
        .devices(personnel.tracking.uuid)
        .where((test) => !devices.contains(test))
        .toList();

    final tracking = await params.context.bloc<TrackingBloc>().replace(
          personnel.tracking.uuid,
          devices: keepDevices,
        );
    return dartz.right(tracking);
  }
}

/// Mobilize current [user] if not already mobilized
Future<dartz.Either<bool, Personnel>> mobilizeUser() => MobilizeUser()(PersonnelParams());

class MobilizeUser extends UseCase<bool, Personnel, PersonnelParams> implements BlocEventHandler<PersonnelsLoaded> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    if (params.incidentBloc.isUnselected) {
      return dartz.left(false);
    }

    final user = params.user;
    assert(user != null, "UserBloc contains no user");
    try {
      var personnel = _findUser(params, user);
      if (personnel == null) {
        final org = await FleetMapService().fetchOrganization(Defaults.orgId);
        personnel = await params.bloc.create(Personnel(
          uuid: Uuid().v4(),
          userId: user.userId,
          fname: user.fname,
          lname: user.lname,
          phone: user.phone,
          status: PersonnelStatus.Mobilized,
          affiliation: org.toAffiliationFromUser(user),
        ));
        return dartz.right(personnel);
      } else if (personnel.status != PersonnelStatus.Mobilized) {
        return _transitionPersonnel(
          PersonnelParams(personnel: personnel),
          PersonnelStatus.Mobilized,
        );
      }
      // Already mobilized
      return dartz.right(personnel);
    } on Exception catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
    return dartz.left(false);
  }

  @override
  void handle(Bloc bloc, PersonnelsLoaded event) => call(PersonnelParams(bloc: bloc));
}

Personnel _findUser(PersonnelParams params, User user) {
  return params.bloc.find(
    user,
    exclude: const [],
  ).firstOrNull;
}

/// Transition personnel to mobilized state
Future<dartz.Either<bool, Personnel>> mobilizePersonnel(
  Personnel personnel,
) =>
    MobilizePersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class MobilizePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.Mobilized,
      action: "Mobiliser ${params.data.name}",
      message: "Dette endre status til mobilisert. Vil du fortsette?",
    );
  }
}

Future<dartz.Either<bool, Personnel>> checkInPersonnel(
  Personnel personnel,
) =>
    DeployPersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class DeployPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.OnScene,
      action: "Sjekk inn ${params.data.name}",
      message: "Dette endre status til ankommet. Vil du fortsette?",
    );
  }
}

/// Transition personnel to retired state
Future<dartz.Either<bool, Personnel>> retirePersonnel(
  Personnel personnel,
) =>
    RetirePersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class RetirePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.Retired,
      action: "Dimitter ${params.data.name}",
      message: "Dette vil stoppe sporing og dimmitere mannskapet. Vil du fortsette?",
    );
  }
}

Future<dartz.Either<bool, Personnel>> _transitionPersonnel(PersonnelParams params, PersonnelStatus status,
    {String action, String message}) async {
  assert(params.data != null, "Personnel must be supplied");
  if (action != null) {
    var response = await prompt(params.overlay.context, action, message);
    if (!response) return dartz.Left(false);
  }
  final personnel = await params.bloc.update(params.data.cloneWith(status: status));
  return dartz.Right(personnel);
}

/// Delete personnel
Future<dartz.Either<bool, PersonnelState>> deletePersonnel(
  Personnel personnel,
) =>
    DeletePersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class DeletePersonnel extends UseCase<bool, PersonnelState, PersonnelParams> {
  @override
  Future<dartz.Either<bool, PersonnelState>> execute(params) async {
    assert(params.data != null, "Personnel must be supplied");
    var response = await prompt(
      params.overlay.context,
      "Slett ${params.data.name}",
      "Dette vil slette alle data fra sporinger og fjerne mannskapet fra aksjonen. "
          "Endringen kan ikke omgjøres. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);
    await params.bloc.delete(params.data.uuid);
    return dartz.Right(params.bloc.state);
  }
}
