

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';

import 'Division.dart';

abstract class Department extends Aggregate<Map<String, dynamic>> {
  Department({
    required String uuid,
    required this.name,
    required this.suffix,
    required this.division,
    required this.active,
  }) : super(uuid, fields: [
          name,
          suffix,
          division,
          active,
        ]);

  /// Department name
  final String? name;

  /// FleetMap number suffix
  final String? suffix;

  /// Reference to division parent
  final AggregateRef<Division>? division;

  /// Department status
  final bool? active;

  /// Get [Department] reference
  AggregateRef<Department>? toRef();
}
