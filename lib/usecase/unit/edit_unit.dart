import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/usecase/unit/unit.dart';
import 'package:SarSys/usecase/use_case.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';

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
