import 'package:equatable/equatable.dart';

import 'process_step.dart';

abstract class Process extends Equatable {
  Process(this.uuid, this.name, this.steps);
  final String uuid;
  final String name;
  final List<ProcessStep> steps;
}
