import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class OperationCommand<S, T> extends BlocCommand<S, T> {
  OperationCommand(
    S data, {
    props = const [],
  }) : super(data, props);
}

class LoadOperations extends OperationCommand<void, List<Operation>> {
  LoadOperations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class CreateOperation extends OperationCommand<Operation, Operation> {
  final bool selected;
  final List<String> units;
  final Incident incident;
  CreateOperation(
    Operation operation, {
    this.selected = true,
    this.units,
    this.incident,
  }) : super(operation, props: [selected, incident, units]);

  @override
  String toString() => '$runtimeType {data: $data, selected: $selected, incident: $incident, units: $units}';
}

class UpdateOperation extends OperationCommand<Operation, Operation> {
  final bool selected;
  final Incident incident;
  UpdateOperation(
    Operation operation, {
    this.selected = true,
    this.incident,
  }) : super(operation, props: [selected, incident]);

  @override
  String toString() => '$runtimeType {data: $data, selected: $selected, incident: $incident}';
}

class SelectOperation extends OperationCommand<String, Operation> {
  SelectOperation(String uuid) : super(uuid);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class UnselectOperation extends OperationCommand<void, Operation> {
  UnselectOperation() : super(null);

  @override
  String toString() => '$runtimeType';
}

class DeleteOperation extends OperationCommand<String, Operation> {
  DeleteOperation(String uuid) : super(uuid);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class UnloadOperations extends OperationCommand<void, List<Operation>> {
  UnloadOperations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}
