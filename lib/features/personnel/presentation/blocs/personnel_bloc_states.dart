// @dart=2.11

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';

/// ---------------------
/// Normal States
/// ---------------------

abstract class PersonnelState<T> extends PushableBlocEvent<T> {
  PersonnelState(
    T data, {
    StackTrace stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

  bool isError() => this is PersonnelBlocError;
  bool isEmpty() => this is PersonnelsEmpty;
  bool isLoaded() => this is PersonnelsLoaded;
  bool isCreated() => this is PersonnelCreated;
  bool isUpdated() => this is PersonnelUpdated;
  bool isDeleted() => this is PersonnelDeleted;
  bool isUserMobilized() => this is UserMobilized;
  bool isUnloaded() => this is PersonnelsUnloaded;

  bool isStatusChanged() => false;
  bool isMobilized() => (data is Personnel) ? (data as Personnel).isMobilized : false;
  bool isTracked() => (data is Personnel) ? (data as Personnel).tracking?.uuid != null : false;
  bool isRetired() => (data is Personnel) ? (data as Personnel).status == PersonnelStatus.retired : false;
}

class PersonnelsEmpty extends PersonnelState<Null> {
  PersonnelsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class PersonnelsLoaded extends PersonnelState<List<String>> {
  PersonnelsLoaded(
    List<String> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {personnels: $data, isRemote: $isRemote}';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => '$runtimeType {personnel: $data, isRemote: $isRemote}';
}

class UserMobilized extends PersonnelCreated {
  UserMobilized(
    this.user,
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  final User user;

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  String toString() => '$runtimeType {personnel: $data, user: $user, isRemote: $isRemote}';
}

class PersonnelUpdated extends PersonnelState<Personnel> {
  final Personnel previous;
  PersonnelUpdated(
    Personnel data,
    this.previous, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [previous]);

  @override
  bool isTracked() => data.tracking?.uuid != null;

  @override
  bool isStatusChanged() => data.status != previous.status;

  @override
  String toString() => '$runtimeType {data: $data, previous: $previous, isRemote: $isRemote}';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(
    Personnel data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

class PersonnelsUnloaded extends PersonnelState<List<Personnel>> {
  PersonnelsUnloaded(List<Personnel> personnel) : super(personnel);

  @override
  String toString() => '$runtimeType {data: $data}';
}

/// ---------------------
/// Error States
/// ---------------------

class PersonnelBlocError extends PersonnelState<Object> {
  PersonnelBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {data: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class PersonnelBlocException implements Exception {
  PersonnelBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final PersonnelState state;
  final StackTrace stackTrace;
  final Object command;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
