import 'package:equatable/equatable.dart';

class ProcessStep extends Equatable {
  ProcessStep(this.index, this.name);
  final int index;
  final String name;
}
