import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/streams.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:catcher/core/catcher.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

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

    var result = await showDialog<Pair<Incident, List<String>>>(
      context: params.overlay.context,
      builder: (context) => IncidentEditor(
        ipp: params.ipp,
        controller: params.controller,
      ),
    );
    if (result == null) return dartz.Left(false);

    // Create incident
    final incident = await params.bloc.create(result.left);

    // Create default units?
    if (result.right.isNotEmpty) {
      final templates = result.right;
      final org = await FleetMapService().fetchOrganization(Defaults.orgId);
      final config = params.context.bloc<AppConfigBloc>().config;
      final department = org.divisions[config.divId]?.departments[config.depId] ?? '';
      templates.forEach((template) async {
        final unit = params.context.bloc<UnitBloc>().fromTemplate(
              department,
              template,
            );
        if (unit != null) {
          await params.context.bloc<UnitBloc>().create(unit);
        }
      });
    }
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
    assert(params.uuid != null, "Incident uuid must be given");
    try {
      final incident = await params.bloc.select(
        params.uuid,
      );
      return dartz.Right(incident);
    } on Exception catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
    return dartz.Left(false);
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
    final user = params.context.bloc<UserBloc>().user;
    assert(user != null, "UserBloc contains no user");

    if (shouldRegister(params)) {
      return await _mobilize(
        params,
        user,
      );
    }

    final join = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du legges nå til aksjonen som mannskap. Vil du fortsette?',
    );

    if (join == true) {
      await params.bloc.select(params.data.uuid);
      await waitThoughtStates(
        params.context.bloc<PersonnelBloc>(),
        expected: [PersonnelsLoaded],
      );
      return _mobilize(params, user);
    }
    return dartz.Left(false);
  }

  bool shouldRegister(IncidentParams params) => !params.bloc.isUnset && params.data.uuid == params.bloc.selected?.uuid;

  Future<dartz.Either<bool, Personnel>> _mobilize(IncidentParams params, User user) async {
    try {
      var personnel = _findPersonnel(params, user);
      if (personnel == null) {
        final org = await FleetMapService().fetchOrganization(Defaults.orgId);
        personnel = await params.context.bloc<PersonnelBloc>().create(Personnel(
              uuid: Uuid().v4(),
              userId: user.userId,
              fname: user.fname,
              lname: user.lname,
              phone: user.phone,
              status: PersonnelStatus.Mobilized,
              affiliation: org.toAffiliationFromUser(user),
            ));
      }
      return dartz.right(personnel);
    } on Exception catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
    return dartz.left(false);
  }
}

Future<dartz.Either<bool, Personnel>> leaveIncident() => LeaveIncident()(IncidentParams());

class LeaveIncident extends UseCase<bool, Personnel, IncidentParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data == null, "Incident should not be given");
    final user = params.context.bloc<UserBloc>().user;
    assert(user != null, "UserBloc contains no user");

    final leave = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du dimitteres nå fra aksjonen. Vil du fortsette?',
    );

    if (leave) {
      try {
        Personnel personnel = await _retire(params, user);
        await params.bloc.unselect();
        return dartz.Right(personnel);
      } on Exception catch (e, stackTrace) {
        Catcher.reportCheckedError(e, stackTrace);
      }
    }
    return dartz.Left(false);
  }

  Future<Personnel> _retire(IncidentParams params, User user) async {
    var personnel = _findPersonnel(params, user);
    if (personnel != null) {
      personnel = await params.context.bloc<PersonnelBloc>().update(
            personnel.cloneWith(
              status: PersonnelStatus.Retired,
            ),
          );
    }
    return personnel;
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
        controller: params.controller,
      ),
    );
    if (incident == null) return dartz.Left(false);
    incident = await params.bloc.update(incident);
    return dartz.Right(incident);
  }
}

Personnel _findPersonnel(IncidentParams params, User user) {
  return params.context.bloc<PersonnelBloc>().find(
    user,
    exclude: const [],
  ).firstOrNull;
}
