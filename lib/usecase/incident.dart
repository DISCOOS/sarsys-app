import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class IncidentParams extends BlocParams<IncidentBloc, Incident> {
  final Point ipp;
  IncidentParams(
    BuildContext context, {
    Incident incident,
    this.ipp,
  }) : super(context, incident);
}

/// Create incident
Future<dartz.Either<bool, Incident>> createIncident(
  BuildContext context, {
  Point ipp,
}) =>
    CreateIncident()(IncidentParams(context, ipp: ipp));

class CreateIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> call(params) async {
    assert(params.data == null, "Incident should not be supplied");
    final controller = Provider.of<PermissionController>(params.context);

    var result = await showDialog<Pair<Incident, List<String>>>(
      context: params.context,
      builder: (context) => IncidentEditor(
        ipp: params.ipp,
        controller: controller,
      ),
    );
    if (result == null) return dartz.Left(false);
    final incident = await params.bloc.create(result.left);
    if (result.right.isNotEmpty) {
      final org = await AssetsService().fetchOrganization(Defaults.organization);
      final unitBloc = BlocProvider.of<UnitBloc>(params.context);
      final configBloc = BlocProvider.of<AppConfigBloc>(params.context);
      final department = org.divisions[configBloc.config.division]?.departments[configBloc.config.department] ?? '';
      result.right.forEach((template) {
        final unit = unitBloc.fromTemplate(
          department,
          template,
        );
        if (unit != null) unitBloc.create(unit);
      });
    }
    return dartz.Right(incident);
  }
}

Future<dartz.Either<bool, Incident>> editIncident(
  BuildContext context,
  Incident incident,
) =>
    EditIncident()(IncidentParams(context, incident: incident));

class EditIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> call(params) async {
    assert(params.data != null, "Incident is required");
    final controller = Provider.of<PermissionController>(params.context);

    var incident = await showDialog<Incident>(
      context: params.context,
      builder: (context) => IncidentEditor(
        incident: params.data,
        ipp: params.ipp,
        controller: controller,
      ),
    );
    if (incident == null) return dartz.Left(false);
    incident = await params.bloc.update(incident);
    return dartz.Right(incident);
  }
}
