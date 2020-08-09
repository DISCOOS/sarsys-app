import 'dart:async';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/features/operation/presentation/editors/operation_editor.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/domain/usecase/core.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/extensions.dart';

class OperationParams extends BlocParams<OperationBloc, Operation> {
  final Point ipp;
  final String uuid;
  OperationParams({
    Operation operation,
    this.ipp,
    this.uuid,
  }) : super(operation);
}

/// Create operation
Future<dartz.Either<bool, Operation>> createOperation({
  Point ipp,
}) =>
    CreateOperation()(OperationParams(ipp: ipp));

class CreateOperation extends UseCase<bool, Operation, OperationParams> {
  @override
  Future<dartz.Either<bool, Operation>> execute(params) async {
    assert(params.data == null, "Operation should not be supplied");
    _assertUser(params);

    var result = await showDialog<OperationEditorResult>(
      context: params.overlay.context,
      builder: (context) => OperationEditor(
        ipp: params.ipp,
      ),
    );
    if (result == null) {
      return dartz.Left(false);
    }

    // Create Operation
    //
    // * Units will be created with CreateUnits by UnitBloc
    // * User will be mobilized with MobilizeUser by PersonnelBloc
    //
    final operation = await params.bloc.create(
      result.operation,
      selected: true,
      units: result.units,
      incident: result.incident,
    );
    return dartz.Right(operation);
  }
}

Future<dartz.Either<bool, Operation>> selectOperation(
  String uuid,
) =>
    SelectOperation()(OperationParams(uuid: uuid));

class SelectOperation extends UseCase<bool, Operation, OperationParams> {
  @override
  Future<dartz.Either<bool, Operation>> execute(params) async {
    final user = _assertUser(params);
    // Read from storage if not set in params
    final ouuid = params.uuid ??
        await Storage.readUserValue(
          user,
          suffix: OperationBloc.SELECTED_KEY_SUFFIX,
        );

    assert(ouuid != null, "Operation uuid must be given");
    try {
      final operation = await params.bloc.select(ouuid);
      return dartz.Right(operation);
    } on OperationNotFoundBlocException {
      await Storage.deleteUserValue(
        user,
        suffix: OperationBloc.SELECTED_KEY_SUFFIX,
      );
    }
    return dartz.left(false);
  }
}

Future<dartz.Either<bool, Operation>> editOperation(
  Operation operation,
) =>
    EditOperation()(OperationParams(operation: operation));

class EditOperation extends UseCase<bool, Operation, OperationParams> {
  @override
  Future<dartz.Either<bool, Operation>> execute(params) async {
    assert(params.data != null, "Operation is required");

    var result = await showDialog<OperationEditorResult>(
      context: params.overlay.context,
      useRootNavigator: false,
      builder: (context) => OperationEditor(
        ipp: params.ipp,
        operation: params.data,
        incident: params.bloc.incidents[params.data.incident.uuid],
      ),
    );
    if (result == null) return dartz.Left(false);
    final operation = await params.bloc.update(
      result.operation,
      incident: result.incident,
    );
    return dartz.Right(operation);
  }
}

User _assertUser(OperationParams params) {
  final user = params.bloc.userBloc.user;
  assert(user != null, "User must bed authenticated");
  return user;
}

Future<dartz.Either<bool, Personnel>> joinOperation(
  Operation operation,
) =>
    JoinOperation()(OperationParams(operation: operation));

class JoinOperation extends UseCase<bool, Personnel, OperationParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data != null, "Operation is required");
    final user = params.bloc.userBloc.user;
    assert(user != null, "User must be authenticated");

    if (_shouldRegister(params)) {
      return mobilizeUser();
    }

    final join = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du legges nå til aksjonen som mannskap. Vil du fortsette?',
    );

    if (join == true) {
      // PersonnelBloc will mobilize user
      await params.bloc.select(params.data.uuid);
      final personnel = await _findPersonnel(
        params,
        user,
        wait: true,
      );
      return dartz.right(personnel);
    }
    return dartz.Left(false);
  }
}

Future<dartz.Either<bool, Personnel>> leaveOperation() => LeaveOperation()(OperationParams());

class LeaveOperation extends UseCase<bool, Personnel, OperationParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data == null, "Operation should not be given");
    final user = _assertUser(params);

    final leave = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du dimitteres nå fra aksjonen. Vil du fortsette?',
    );

    if (leave) {
      Personnel personnel = await _retire(params, user);
      await params.bloc.unselect();
      params.pushReplacementNamed(OperationsScreen.ROUTE);
      return dartz.Right(personnel);
    }
    return dartz.Left(false);
  }
}

bool _shouldRegister(
  OperationParams params,
) =>
    !params.bloc.isUnselected && params.data.uuid == params.bloc.selected?.uuid;

FutureOr<Personnel> _findPersonnel(OperationParams params, User user, {bool wait = false}) async {
  // Look for existing personnel
  final personnel = params.context.bloc<PersonnelBloc>().findUser(
    userId: user.userId,
    exclude: const [],
  ).firstOrNull;
  // Wait for personnel to be created
  if (wait && personnel == null) {
    return await waitThroughStateWithData<PersonnelState, Personnel>(
      params.context.bloc<PersonnelBloc>(),
      test: (state) => state.isCreated() && (state.data as Personnel).userId == user.userId,
      map: (state) => state.data,
    );
  }
  return personnel;
}

// TODO: Move to new use-case RetireUser in PersonnelBloc
Future<Personnel> _retire(OperationParams params, User user) async {
  var personnel = await _findPersonnel(params, user);
  if (personnel != null) {
    personnel = await params.context.bloc<PersonnelBloc>().update(
          personnel.copyWith(
            status: PersonnelStatus.retired,
          ),
        );
  }
  return personnel;
}
