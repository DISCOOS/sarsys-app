import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/editors/position_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';

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
  Future<dartz.Either<bool, Point>> execute(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.data ??
            Position.fromPoint(
              params.incident.ipp.point,
              source: PositionSource.manual,
            ),
        title: "Endre IPP",
        incident: params.incident,
        controller: params.controller,
      ),
    );
    if (result == null) return dartz.Left(false);
    final point = result.geometry;
    await params.bloc.update(
      params.incident.cloneWith(
        ipp: params.incident.ipp.cloneWith(
          point: point,
        ),
      ),
    );
    return dartz.Right(point);
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
  Future<dartz.Either<bool, Point>> execute(params) async {
    assert(params.incident != null, "Incident must be supplied");
    var result = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.data ??
            Position.fromPoint(
              params.incident.meetup.point,
              source: PositionSource.manual,
            ),
        title: "Endre oppmøte",
        incident: params.incident,
        controller: params.controller,
      ),
    );
    if (result == null) return dartz.Left(false);
    final point = result.geometry;
    await params.bloc.update(
      params.incident.cloneWith(
        meetup: params.incident.meetup.cloneWith(
          point: point,
        ),
      ),
    );
    return dartz.Right(point);
  }
}
