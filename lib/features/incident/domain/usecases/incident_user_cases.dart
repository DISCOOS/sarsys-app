import 'dart:async';

import 'package:SarSys/features/incident/presentation/blocs/incident_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/core/streams.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/features/incident/presentation/editors/incident_editor.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/features/incident/presentation/screens/incidents_screen.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/extensions.dart';

class IncidentParams extends BlocParams<IncidentBloc, Incident> {
  final Point ipp;
  final String uuid;
  IncidentParams({
    Incident incident,
    this.ipp,
    this.uuid,
  }) : super(incident);
}

/// Create incident
Future<dartz.Either<bool, Incident>> createIncident({
  Point ipp,
}) =>
    CreateIncident()(IncidentParams(ipp: ipp));

class CreateIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> execute(params) async {
    assert(params.data == null, "Incident should not be supplied");
    _assertUser(params);

    var result = await showDialog<Pair<Incident, List<String>>>(
      context: params.overlay.context,
      builder: (context) => IncidentEditor(
        ipp: params.ipp,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Create incident
    // * units will be created with CreateUnits in
    // UnitBloc user will be mobilized with
    // MobilizeUser invoked by BlocEvent handler
    // registered in BlocController
    //
    final incident = await params.bloc.create(
      result.left,
      selected: true,
      units: result.right,
    );
    return dartz.Right(incident);
  }
}

Future<dartz.Either<bool, Incident>> selectIncident(
  String uuid,
) =>
    SelectIncident()(IncidentParams(uuid: uuid));

class SelectIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> execute(params) async {
    final user = _assertUser(params);
    // Read from storage if not set in params
    final iuuid = params.uuid ??
        await Storage.readUserValue(
          user,
          suffix: IncidentBloc.SELECTED_IUUID_KEY_SUFFIX,
        );

    assert(iuuid != null, "Incident uuid must be given");
    try {
      final incident = await params.bloc.select(iuuid);
      return dartz.Right(incident);
    } on IncidentNotFoundBlocException {
      await Storage.deleteUserValue(
        user,
        suffix: IncidentBloc.SELECTED_IUUID_KEY_SUFFIX,
      );
    }
    return dartz.left(false);
  }
}

Future<dartz.Either<bool, Personnel>> joinIncident(
  Incident incident,
) =>
    JoinIncident()(IncidentParams(incident: incident));

class JoinIncident extends UseCase<bool, Personnel, IncidentParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data != null, "Incident is required");
    final user = params.bloc.userBloc.user;
    assert(user != null, "User must bed authenticated");

    if (_shouldRegister(params)) {
      return mobilizeUser();
    }

    final join = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du legges nå til aksjonen som mannskap. Vil du fortsette?',
    );

    if (join == true) {
      await params.bloc.select(params.data.uuid);
      final personnel = await _findPersonnel(
        params,
        user,
        wait: true,
      );
      return dartz.right(personnel);
    }
    return dartz.Left(false);
  }
}

Future<dartz.Either<bool, Personnel>> leaveIncident() => LeaveIncident()(IncidentParams());

class LeaveIncident extends UseCase<bool, Personnel, IncidentParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data == null, "Incident should not be given");
    final user = _assertUser(params);

    final leave = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du dimitteres nå fra aksjonen. Vil du fortsette?',
    );

    if (leave) {
      Personnel personnel = await _retire(params, user);
      await params.bloc.unselect();
      params.pushReplacementNamed(IncidentsScreen.ROUTE);
      return dartz.Right(personnel);
    }
    return dartz.Left(false);
  }
}

Future<dartz.Either<bool, Incident>> editIncident(
  Incident incident,
) =>
    EditIncident()(IncidentParams(incident: incident));

class EditIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> execute(params) async {
    assert(params.data != null, "Incident is required");

    var incident = await showDialog<Incident>(
      context: params.overlay.context,
      useRootNavigator: false,
      builder: (context) => IncidentEditor(
        incident: params.data,
        ipp: params.ipp,
      ),
    );
    if (incident == null) return dartz.Left(false);
    incident = await params.bloc.update(incident);
    return dartz.Right(incident);
  }
}

User _assertUser(IncidentParams params) {
  final user = params.bloc.userBloc.user;
  assert(user != null, "User must bed authenticated");
  return user;
}

bool _shouldRegister(
  IncidentParams params,
) =>
    !params.bloc.isUnselected && params.data.uuid == params.bloc.selected?.uuid;

FutureOr<Personnel> _findPersonnel(IncidentParams params, User user, {bool wait = false}) async {
  // Look for existing personnel
  final personnel = params.context.bloc<PersonnelBloc>().find(
    user,
    exclude: const [],
  ).firstOrNull;
  // Wait for personnel to be created
  if (wait && personnel == null) {
    return await waitThroughStateWithData<PersonnelState, Personnel>(
      params.context.bloc<PersonnelBloc>(),
      test: (state) => state.isCreated() && (state.data as Personnel).userId == user.userId,
      map: (state) => state.data,
    );
  }
  return personnel;
}

// TODO: Move to new use-case RetireUser in PersonnelBloc
Future<Personnel> _retire(IncidentParams params, User user) async {
  var personnel = await _findPersonnel(params, user);
  if (personnel != null) {
    personnel = await params.context.bloc<PersonnelBloc>().update(
          personnel.copyWith(
            status: PersonnelStatus.Retired,
          ),
        );
  }
  return personnel;
}
