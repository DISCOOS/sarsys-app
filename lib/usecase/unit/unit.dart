import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/use_case.dart';
import 'package:flutter/widgets.dart';

class UnitParams extends BlocParams<UnitBloc, Unit> {
  UnitParams(BuildContext context, Unit unit) : super(context, unit);
}
