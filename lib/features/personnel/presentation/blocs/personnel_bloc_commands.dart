// @dart=2.11

import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class PersonnelCommand<S, T> extends BlocCommand<S, T> {
  PersonnelCommand(
    S data, {
    props = const [],
    Completer<T> callback,
  }) : super(data, props, callback);
}

class LoadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  LoadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}

class MobilizeUser extends PersonnelCommand<String, Personnel> {
  MobilizeUser(String ouuid, this.user) : super(ouuid);
  final User user;

  @override
  String toString() => '$runtimeType {ouuid: $data, user: $user}';
}

class CreatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  CreatePersonnel(
    this.ouuid,
    Personnel data, {
    Completer<Personnel> callback,
  }) : super(data, callback: callback);

  final String ouuid;

  @override
  String toString() => '$runtimeType {ouuid: $ouuid, personnel: $data}';
}

class UpdatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  UpdatePersonnel(
    Personnel data, {
    Completer<Personnel> callback,
  }) : super(data, callback: callback);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class DeletePersonnel extends PersonnelCommand<Personnel, Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => '$runtimeType {personnel: $data}';
}

class UnloadPersonnels extends PersonnelCommand<String, List<Personnel>> {
  UnloadPersonnels(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}
