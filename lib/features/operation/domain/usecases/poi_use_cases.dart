import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/editors/position_editor.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/core/domain/usecase/core.dart';

class PoiParams extends BlocParams<OperationBloc, Point> {
  final Operation operation;
  PoiParams(
    Point point,
    this.operation,
  ) : super(point);
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editIPP(
  Operation operation, {
  Point point,
}) =>
    EditPoi()(PoiParams(
      point,
      operation,
    ));

class EditPoi extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> execute(params) async {
    assert(params.operation != null, "Incident must be supplied");
    var result = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.data ??
            Position.fromPoint(
              params.operation.ipp.point,
              source: PositionSource.manual,
            ),
        title: "Endre IPP",
        operation: params.operation,
      ),
    );
    if (result == null) return dartz.Left(false);
    final point = result.geometry;
    await params.bloc.update(
      params.operation.copyWith(
        ipp: params.operation.ipp.cloneWith(
          point: point,
        ),
      ),
    );
    return dartz.Right(point);
  }
}

/// Edit given IPP
Future<dartz.Either<bool, Point>> editMeetup(
  Operation operation, {
  Point point,
}) =>
    EditMeetup()(PoiParams(
      point,
      operation,
    ));

class EditMeetup extends UseCase<bool, Point, PoiParams> {
  @override
  Future<dartz.Either<bool, Point>> execute(params) async {
    assert(params.operation != null, "Incident must be supplied");
    var result = await showDialog<Position>(
      context: params.overlay.context,
      builder: (context) => PositionEditor(
        params.data ??
            Position.fromPoint(
              params.operation.meetup.point,
              source: PositionSource.manual,
            ),
        title: "Endre oppmøte",
        operation: params.operation,
      ),
    );
    if (result == null) return dartz.Left(false);
    final point = result.geometry;
    await params.bloc.update(
      params.operation.copyWith(
        meetup: params.operation.meetup.cloneWith(
          point: point,
        ),
      ),
    );
    return dartz.Right(point);
  }
}
