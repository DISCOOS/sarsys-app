import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PoiParams extends BlocParams<IncidentBloc, Point> {
  final Incident incident;
  PoiParams(
    BuildContext context,
    Point point,
    this.incident,
  ) : super(context, point);
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editIPP(
  BuildContext context,
  Incident incident, {
  Point point,
}) =>
    EditPoi()(PoiParams(
      context,
      point,
      incident,
    ));

class EditPoi extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Point>(
      context: params.context,
      builder: (context) => PointEditor(
        params.data ?? params.incident.ipp.point,
        title: "Endre IPP",
        incident: params.incident,
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(params.incident.cloneWith(ipp: params.incident.ipp.cloneWith(point: result)));
    return dartz.Right(result);
  }
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editMeetup(
  BuildContext context,
  Incident incident, {
  Point point,
}) =>
    EditMeetup()(PoiParams(
      context,
      point,
      incident,
    ));

class EditMeetup extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Point>(
      context: params.context,
      builder: (context) => PointEditor(
        params.data ?? params.incident.meetup.point,
        title: "Endre oppmøte",
        incident: params.incident,
        controller: PermissionController(configBloc: BlocProvider.of<AppConfigBloc>(params.context)),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(params.incident.cloneWith(ipp: params.incident.meetup.cloneWith(point: result)));
    return dartz.Right(result);
  }
}
