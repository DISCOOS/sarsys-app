import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

import 'operation_commands.dart';

/// ---------------------
/// Normal States
/// ---------------------
abstract class OperationState<T> extends PushableBlocEvent<T> {
  OperationState(
    T data, {
    props = const [],
    StackTrace stackTrace,
    bool isRemote = false,
  }) : super(
          data,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

  bool isEmpty() => this is OperationsEmpty;
  bool isLoaded() => this is OperationsLoaded;
  bool isCreated() => this is OperationCreated;
  bool isUpdated() => this is OperationUpdated;
  bool isDeleted() => this is OperationDeleted;
  bool isError() => this is OperationBlocError;
  bool isUnselected() => this is OperationUnselected;
  bool isSelected() => this is OperationSelected;

  /// Check if data referencing [Operation.uuid] should be loaded
  /// This method will return true if
  /// 1. Operation was selected
  /// 2. Operation was a status that should load data
  /// 3. [Operation.uuid] in [OperationState.data] is equal to [ouuid] given
  bool shouldLoad(String ouuid,
          {List<OperationStatus> include: const [
            OperationStatus.completed,
          ]}) =>
      isSelected() &&
      (data as Operation).uuid != ouuid &&
      !include.contains(
        (data as Operation).status,
      );

  /// Check if data referencing [Operation.uuid] should be unloaded
  /// This method will return true if
  /// 1. Operation was unselected
  /// 2. Operation was changed to a status that should unload data
  /// 3. [Operation.uuid] in [OperationState.data] is equal to [ouuid] given
  bool shouldUnload(String ouuid,
          {List<OperationStatus> include: const [
            OperationStatus.completed,
          ]}) =>
      isEmpty() ||
      isUnselected() ||
      (isUpdated() && (data as Operation).uuid == ouuid) &&
          include.contains(
            (data as Operation).status,
          );
}

class OperationsEmpty extends OperationState<void> {
  OperationsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class OperationUnselected extends OperationState<Operation> {
  OperationUnselected([Operation operation]) : super(operation);

  @override
  String toString() => '$runtimeType {operation: $data}';
}

class OperationsLoaded extends OperationState<Iterable<String>> {
  OperationsLoaded(
    Iterable<String> data, {
    this.incidents,
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [incidents]);

  final List<String> incidents;

  @override
  String toString() => '$runtimeType {'
      'operations: $data, '
      'isRemote: $isRemote, '
      'incidents: $incidents, '
      '}';
}

class OperationCreated extends OperationState<Operation> {
  final bool selected;
  final Incident incident;
  final List<String> units;
  OperationCreated(
    Operation data, {
    this.units,
    this.incident,
    this.selected = true,
    bool isRemote = false,
  }) : super(data, isRemote: isRemote, props: [selected, incident, units]);

  @override
  String toString() => '$runtimeType '
      '{operation: $data, '
      'selected: $selected, '
      'units: $units, '
      'isRemote: $isRemote'
      '}';
}

class OperationIncidentUpdated extends OperationState<Incident> {
  final Incident previous;
  final Operation operation;
  OperationIncidentUpdated(
    Incident next,
    this.previous,
    this.operation, {
    bool isRemote = false,
  }) : super(next, isRemote: isRemote, props: [
          operation,
          previous,
        ]);

  @override
  String toString() => '$runtimeType {'
      'operation: $operation, '
      'incident: $data, '
      'isRemote: $isRemote'
      'previous: $previous'
      '}';
}

class OperationUpdated extends OperationState<Operation> {
  final bool selected;
  final Incident incident;
  final Operation previous;
  OperationUpdated(
    Operation next,
    this.previous, {
    this.incident,
    this.selected = true,
    bool isRemote = false,
  }) : super(next, isRemote: isRemote, props: [
          incident,
          selected,
          previous,
        ]);

  @override
  String toString() => '$runtimeType {'
      'operation: $data, '
      'selected: $selected, '
      'incident: $incident, '
      'isRemote: $isRemote'
      'previous: $previous'
      '}';
}

class OperationSelected extends OperationState<Operation> {
  OperationSelected(Operation data) : super(data);

  @override
  String toString() => '$runtimeType {operation: $data}';
}

class OperationDeleted extends OperationState<Operation> {
  OperationDeleted(
    Operation data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {operation: $data, isRemote: $isRemote}';
}

class OperationsUnloaded extends OperationState<Iterable<Operation>> {
  OperationsUnloaded(Iterable<Operation> operations) : super(operations);

  @override
  String toString() => '$runtimeType {operations: $data}';
}

/// ---------------------
/// Error States
/// ---------------------
class OperationBlocError extends OperationState<Object> {
  OperationBlocError(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------
class OperationBlocException implements Exception {
  OperationBlocException(this.error, this.state, {this.command, this.stackTrace});
  final Object error;
  final OperationState state;
  final StackTrace stackTrace;
  final OperationCommand command;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}

class OperationNotFoundBlocException extends OperationBlocException {
  OperationNotFoundBlocException(
    String ouuid,
    OperationState state, {
    OperationCommand command,
    StackTrace stackTrace,
  }) : super('Operation $ouuid not found locally', state, command: command, stackTrace: stackTrace);
}
