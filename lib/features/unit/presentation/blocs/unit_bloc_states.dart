

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';

/// ---------------------
/// Normal States
/// ---------------------

abstract class UnitState<T> extends PushableBlocEvent<T> {
  UnitState(
    Object? data, {
    StackTrace? stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data as T,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

  bool isError() => this is UnitBlocError;
  bool isEmpty() => this is UnitsEmpty;
  bool isLoaded() => this is UnitsLoaded;
  bool isCreated() => this is UnitCreated;
  bool isUpdated() => this is UnitUpdated;
  bool isDeleted() => this is UnitDeleted;
  bool isUnloaded() => this is UnitsUnloaded;

  bool isStatusChanged() => false;
  bool isTracked() => (data is Unit) ? (data as Unit).tracking.uuid != null : false;
  bool isRetired() => (data is Unit) ? (data as Unit).status == UnitStatus.retired : false;
}

class UnitsEmpty extends UnitState<Null> {
  UnitsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class UnitsLoaded extends UnitState<List<String>> {
  UnitsLoaded(
    List<String?> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

class UnitCreated extends UnitState<Unit> {
  final Position? position;
  final List<Device>? devices;
  UnitCreated(
    Unit? data, {
    this.position,
    this.devices,
    bool isRemote = false,
  }) : super(
          data,
          isRemote: isRemote,
          props: [position, devices],
        );

  @override
  String toString() => '$runtimeType {'
      'unit: $data, '
      'position: $position, '
      'devices: $devices,'
      'isRemote: $isRemote'
      '}';
}

class UnitUpdated extends UnitState<Unit> {
  final Unit? previous;
  UnitUpdated(
    Unit? data,
    this.previous, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [previous]);

  @override
  bool isStatusChanged() => data.status != previous!.status;

  @override
  String toString() => '$runtimeType {unit: $data, previous: $previous, isRemote: $isRemote}';
}

class UnitDeleted extends UnitState<Unit> {
  UnitDeleted(
    Unit? data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

class UnitsUnloaded extends UnitState<List<Unit>> {
  UnitsUnloaded(
    List<Unit?> units, {
    bool isRemote = false,
  }) : super(units, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {data: $data, isRemote: $isRemote}';
}

/// ---------------------
/// Error States
/// ---------------------

class UnitBlocError extends UnitState<Object> {
  UnitBlocError(
    Object error, {
    StackTrace? stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class UnitBlocException implements Exception {
  UnitBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final UnitState state;
  final StackTrace? stackTrace;
  final Object? command;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}
