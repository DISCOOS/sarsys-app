// @dart=2.11

import 'dart:async';

import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/presentation/keyboard_avoider.dart';
import 'package:SarSys/features/operation/presentation/pages/passcode_page.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/pages/download_page.dart';
import 'package:SarSys/features/operation/presentation/screens/open_operation_screen.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/operation/presentation/editors/operation_editor.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/domain/usecase/core.dart';
import 'package:SarSys/core/utils/ui.dart';

class OperationParams extends BlocParams<OperationBloc, Operation> {
  OperationParams({
    Operation operation,
    this.ipp,
    this.uuid,
  }) : super(operation);
  final Point ipp;
  final String uuid;
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

Future<dartz.Either<bool, Operation>> openOperation(
  String uuid,
) =>
    OpenOperation()(OperationParams(uuid: uuid));

class OpenOperation extends UseCase<bool, Operation, OperationParams> {
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
      // TODO: Use OpenOperationScreen here
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

    if (_shouldJoin(params)) {
      return _join(params);
    }

    final personnel = await _mobilize(params);
    if (personnel != null) {
      params.pushReplacementNamed(UserScreen.ROUTE_OPERATION);
      return dartz.right(personnel);
    }
    return dartz.Left(false);
  }
}

Future<dartz.Either<bool, bool>> escalateToCommand() => EscalateToCommand()(
      OperationParams(),
    );

class EscalateToCommand extends UseCase<bool, bool, OperationParams> {
  @override
  Future<dartz.Either<bool, bool>> execute(params) async {
    assert(params.data == null, "Operation should not be given");

    final operation = params.bloc.selected;
    final leave = await showDialog<bool>(
      context: params.overlay.context,
      builder: (context) => Scaffold(
        body: KeyboardAvoider(
          child: PasscodePage(
            requireCommand: true,
            operation: operation,
            onComplete: (result) => Navigator.pop(context, result),
            onAuthorize: (operation, passcode) async {
              final authorized = await params.bloc.userBloc.authorize(
                operation,
                passcode,
              );
              if (authorized) {
                return params.bloc.userBloc.getAuthorization(operation).withCommanderCode;
              }
              return authorized;
            },
          ),
        ),
      ),
    );

    if (leave) {
      return dartz.Right(leave);
    }
    return dartz.Left(false);
  }
}

Future<dartz.Either<bool, Personnel>> leaveOperation() => LeaveOperation()(
      OperationParams(),
    );

class LeaveOperation extends UseCase<bool, Personnel, OperationParams> {
  @override
  Future<dartz.Either<bool, Personnel>> execute(params) async {
    assert(params.data == null, "Operation should not be given");

    final leave = await prompt(
      params.overlay.context,
      'Bekreftelse',
      'Du dimitteres nå fra aksjonen. Vil du fortsette?',
    );

    if (leave) {
      Personnel personnel = await _leave(params);
      return dartz.Right(personnel);
    }
    return dartz.Left(false);
  }
}

bool _shouldJoin(
  OperationParams params,
) =>
    params.bloc.isUnselected || params.data.uuid != params.bloc.selected?.uuid;

Future<dartz.Either<bool, Personnel>> _join(
  OperationParams params,
) async {
  final join = await prompt(
    params.overlay.context,
    'Bekreftelse',
    'Du legges nå til aksjonen som mannskap. Vil du fortsette?',
  );

  if (join == true && !params.bloc.userBloc.isAuthorized(params.data)) {
    final personnel = await showDialog<Personnel>(
      context: params.overlay.context,
      builder: (context) => OpenOperationScreen(
        operation: params.data,
        onAuthorize: (operation, passcode) => params.bloc.userBloc.authorize(
          operation,
          passcode,
        ),
        requirePasscode: 0,
        onCancel: (step) {
          if (step == OpenOperationScreen.DOWNLOAD && params.bloc.selected == params.data) {
            leaveOperation();
          }
        },
        onDownload: (operation, onProgress) async {
          DownloadProgress.percent(0).linearToPercent(
            onProgress,
            100,
          );
          // PersonnelBloc will mobilize user
          await params.bloc.select(operation.uuid);
          // Wait for blocs to download all data
          await _onLoadedAsync<UnitBloc>(params);
          await _onLoadedAsync<PersonnelBloc>(params);
          return _mobilize(params);
        },
      ),
    );

    if (personnel != null) {
      params.pushReplacementNamed(UserScreen.ROUTE_OPERATION);
      return dartz.right(personnel);
    }
  }
  if (join == true && params.bloc.userBloc.isAuthorized(params.data)) {
    final personnel = await showDialog<Personnel>(
      context: params.overlay.context,
      builder: (context) => OpenOperationScreen(
        operation: params.data,
        onAuthorize: (operation, passcode) => params.bloc.userBloc.authorize(
          operation,
          passcode,
        ),
        requirePasscode: 1,
        onCancel: (step) {
          if (step == OpenOperationScreen.DOWNLOAD && params.bloc.selected == params.data) {
            leaveOperation();
          }
        },
        onDownload: (operation, onProgress) async {
          DownloadProgress.percent(0).linearToPercent(
            onProgress,
            100,
          );
          // PersonnelBloc will mobilize user
          await params.bloc.select(operation.uuid);
          // Wait for blocs to download all data
          await _onLoadedAsync<UnitBloc>(params);
          await _onLoadedAsync<PersonnelBloc>(params);
          return _mobilize(params);
        },
      ),
    );

    if (personnel != null) {
      params.pushReplacementNamed(UserScreen.ROUTE_OPERATION);
      return dartz.right(personnel);
    }
  }
  return dartz.Left(false);
}

Future _onLoadedAsync<B extends BaseBloc<dynamic, dynamic, dynamic>>(OperationParams params) {
  final bloc = params.context.read<B>();
  if (bloc is ConnectionAwareBloc) {
    return (bloc as ConnectionAwareBloc).onLoadedAsync();
  }
  return Future.value();
}

Future<Personnel> _mobilize(OperationParams params) async {
  final personnels = params.context.read<PersonnelBloc>();
  var personnel = personnels.findMobilizedUserOrReuse();
  personnel ??= await personnels.mobilizeUser();
  assert(
    personnel != null,
    'User ${params.bloc.userBloc.user} not mobilized',
  );
  return personnel;
}

// TODO: Move to new use-case RetireUser in PersonnelBloc
Future<Personnel> _retire(OperationParams params) async {
  final personnels = params.context.read<PersonnelBloc>();
  var personnel = personnels.findMobilizedUserOrReuse();
  if (personnel != null) {
    personnel = await personnels.update(
      personnel.copyWith(
        status: PersonnelStatus.retired,
      ),
    );
    // // Ensure state is pushed if online
    // if (bloc.isOnline) {
    //   await bloc.repo.onRemote(personnel.uuid).timeout(
    //         const Duration(seconds: 5),
    //       );
    // }
  }
  return personnel;
}

Future<Personnel> _leave(OperationParams params) async {
  Personnel personnel = await _retire(params);
  await params.bloc.unselect();
  params.pushReplacementNamed(OperationsScreen.ROUTE);
  return personnel;
}
