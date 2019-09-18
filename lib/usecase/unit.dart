import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/core.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';

class UnitParams extends BlocParams<UnitBloc, Unit> {
  UnitParams(BuildContext context, Unit unit) : super(context, unit);
}

Future<dartz.Either<bool, UnitState>> editUnit(params) => EditUnit()(params);

class EditUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    var result = await showDialog<UnitEditorResult>(
      context: params.context,
      builder: (context) => UnitEditor(unit: params.data),
    );
    return (result == null) ? dartz.Left(false) : dartz.Right(params.bloc.currentState);
  }
}

Future<dartz.Either<bool, UnitState>> retireUnit(params) => RetireUnit()(params);

class RetireUnit extends UseCase<bool, UnitState, UnitParams> {
  @override
  Future<dartz.Either<bool, UnitState>> call(params) async {
    var response = await prompt(
      params.context,
      "Oppløs ${params.data.name}",
      "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
    );
    if (!response) return dartz.Left(false);

    await params.bloc.update(params.data.cloneWith(status: UnitStatus.Retired));
    return dartz.Right(params.bloc.currentState);
  }
}
