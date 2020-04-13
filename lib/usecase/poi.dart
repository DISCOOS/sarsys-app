import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PoiParams extends BlocParams<IncidentBloc, Point> {
  final Incident incident;
  PoiParams(
    Point point,
    this.incident,
  ) : super(point);
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editIPP(
  Incident incident, {
  Point point,
}) =>
    EditPoi()(PoiParams(
      point,
      incident,
    ));

class EditPoi extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Point>(
      context: params.overlay.context,
      builder: (context) => PointEditor(
        params.data ?? params.incident.ipp.point,
        title: "Endre IPP",
        incident: params.incident,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(params.incident.cloneWith(ipp: params.incident.ipp.cloneWith(point: result)));
    return dartz.Right(result);
  }
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editMeetup(
  Incident incident, {
  Point point,
}) =>
    EditMeetup()(PoiParams(
      point,
      incident,
    ));

class EditMeetup extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> call(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Point>(
      context: params.overlay.context,
      builder: (context) => PointEditor(
        params.data ?? params.incident.meetup.point,
        title: "Endre oppmøte",
        incident: params.incident,
        controller: Provider.of<PermissionController>(params.context),
      ),
    );
    if (result == null) return dartz.Left(false);
    await params.bloc.update(params.incident.cloneWith(meetup: params.incident.meetup.cloneWith(point: result)));
    return dartz.Right(result);
  }
}
