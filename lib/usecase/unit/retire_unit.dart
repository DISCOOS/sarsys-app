import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/unit/unit.dart';
import 'package:SarSys/usecase/use_case.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:dartz/dartz.dart' as dartz;

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
