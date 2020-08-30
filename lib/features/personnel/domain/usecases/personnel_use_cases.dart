import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/affiliation/presentation/pages/affiliations_page.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/features/tracking/presentation/editors/position_editor.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/presentation/editors/personnel_editor.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/personnel/presentation/pages/personnels_page.dart';
import 'package:SarSys/core/domain/usecase/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:catcher/core/catcher.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/extensions.dart';
import 'package:uuid/uuid.dart';

class PersonnelParams extends BlocParams<PersonnelBloc, Personnel> {
  final Position position;
  final List<Device> devices;
  final Affiliation affiliation;
  OperationBloc get operationBloc => bloc.operationBloc;
  AffiliationBloc get affiliationBloc => bloc.affiliationBloc;
  User get user => operationBloc.userBloc.user;
  PersonnelParams({
    Personnel personnel,
    this.devices,
    this.position,
    this.affiliation,
    PersonnelBloc bloc,
  }) : super(personnel, bloc: bloc);
}

/// Create personnel with tracking of given devices
Future<dartz.Either<bool, Personnel>> createPersonnel({
  List<Device> devices,
  Affiliation affiliation,
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

    // Will create affiliation if not exists
    final affiliation = params.affiliation ??
        await params.context.bloc<AffiliationBloc>().temporary(
              result.data,
              result.affiliation,
            );

    // Will create personnel and tracking
    final personnel = await params.bloc.create(result.data.copyWith(
      affiliation: affiliation.toRef(),
    ));

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

/// Transition personnel to mobilized state
Future<dartz.Either<bool, Personnel>> mobilizePersonnel({
  Personnel personnel,
}) =>
    MobilizePersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class MobilizePersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    // Register new personnel?
    if (params.data == null) {
      // Only show selectable affiliations
      final existing = _selectables(params);
      final affiliation = await selectOrCreateAffiliation(
        params.overlay.context,
        where: (affiliation) => !existing.contains(affiliation.uuid),
      );
      // User cancelled mobilization?
      if (affiliation == null) {
        return dartz.left(false);
      }
      // Create personnel from given affiliation?
      final personnel = _findPersonnel(params, affiliation);
      if (personnel == null) {
        final person = params.context.bloc<AffiliationBloc>().persons[affiliation.person.uuid];
        return dartz.right(await params.bloc.create(PersonnelModel(
          uuid: Uuid().v4(),
          person: person,
          status: PersonnelStatus.alerted,
          tracking: TrackingUtils.newRef(),
          affiliation: affiliation.toRef(),
        )));
      }
      // Re-mobilize personnel?
      if (personnel.status == PersonnelStatus.retired) {
        return dartz.right(await params.bloc.update(personnel.copyWith(
          status: PersonnelStatus.alerted,
        )));
      }
      return dartz.right(personnel);
    }

    return await _transitionPersonnel(
      params,
      PersonnelStatus.alerted,
      action: "Mobiliser ${params.data.name}",
      message: "Dette endre status til varlset. Vil du fortsette?",
    );
  }

  Personnel _findPersonnel(PersonnelParams params, Affiliation affiliation) =>
      params.bloc.repo.find(where: (p) => p.person?.uuid == affiliation.person.uuid).firstOrNull;

  Iterable<String> _selectables(PersonnelParams params) =>
      params.bloc.repo.values.where((p) => p.status != PersonnelStatus.retired).map((p) => p.affiliation.uuid);
}

/// Mobilize current [user] if not already mobilized
Future<dartz.Either<bool, Personnel>> mobilizeUser() => MobilizeUser()(PersonnelParams());

class MobilizeUser extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    if (params.operationBloc.isUnselected) {
      return dartz.left(false);
    }
    assert(params.user != null, "UserBloc contains no user");
    try {
      return dartz.right(await params.bloc.mobilizeUser());
    } on Exception catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
    return dartz.left(false);
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
    final result = await showDialog<PersonnelParams>(
      context: params.overlay.context,
      builder: (context) => PersonnelEditor(
        personnel: params.data,
        devices: params.devices,
        affiliation: params.affiliationBloc.repo[params.data.affiliation.uuid],
      ),
    );
    if (result == null) return dartz.Left(false);

    // Update personnel and affiliation
    // If was retired, tracking bloc will handle tracking
    final personnel = await params.bloc.update(result.data);
    await params.context.bloc<AffiliationBloc>().update(result.affiliation);

    // Only update tracking if not retired
    if (PersonnelStatus.retired != personnel.status) {
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

/// Add given devices to tracking of given personnel
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
    final personnel = params.data != null
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

/// Remove given devices from tracking of personnel.
/// If no devices are supplied, all devices tracked
/// by personnel are removed
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

/// Register personnel as ingress on scene
Future<dartz.Either<bool, Personnel>> ingressPersonnel(
  Personnel personnel,
) =>
    IngressPersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class IngressPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.enroute,
    );
  }
}

/// Check in personnel on scene
Future<dartz.Either<bool, Personnel>> checkInPersonnel(
  Personnel personnel,
) =>
    CheckInPersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class CheckInPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.onscene,
    );
  }
}

/// Check out personnel from on scene
Future<dartz.Either<bool, Personnel>> checkOutPersonnel(
  Personnel personnel,
) =>
    CheckOutPersonnel()(PersonnelParams(
      personnel: personnel,
    ));

class CheckOutPersonnel extends UseCase<bool, Personnel, PersonnelParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    return await _transitionPersonnel(
      params,
      PersonnelStatus.leaving,
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
    // User must use leaveOperation
    if (params.user.userId != null && params.user.userId == params.data.userId) {
      return leaveOperation();
    }

    return await _transitionPersonnel(
      params,
      PersonnelStatus.retired,
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
  final personnel = await params.bloc.update(
    params.data.copyWith(status: status),
  );
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
