import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IncidentParams extends BlocParams<IncidentBloc, Incident> {
  final Point ipp;
  IncidentParams(
    BuildContext context, {
    Incident incident,
    this.ipp,
  }) : super(context, incident);
}

Future<dartz.Either<bool, Incident>> createIncident(IncidentParams params) => CreateIncident()(params);

class CreateIncident extends UseCase<bool, Incident, IncidentParams> {
  @override
  Future<dartz.Either<bool, Incident>> call(params) async {
    assert(params.data == null, "Incident should not be supplied");
    final controller = Provider.of<PermissionController>(params.context);

    var incident = await showDialog<Incident>(
      context: params.context,
      builder: (context) => IncidentEditor(
        ipp: params.ipp,
        controller: controller,
      ),
    );
    if (incident == null) return dartz.Left(false);
    incident = await params.bloc.create(incident);
    return dartz.Right(incident);
  }
}

Future<dartz.Either<bool, Incident>> editIncident(IncidentParams params) => EditIncident()(params);

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
