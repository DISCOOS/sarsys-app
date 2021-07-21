// @dart=2.11

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:meta/meta.dart';

import 'Organisation.dart';

abstract class Division extends Aggregate<Map<String, dynamic>> {
  Division({
    @required String uuid,
    @required this.name,
    @required this.organisation,
    @required this.suffix,
    @required this.departments,
    @required this.active,
  }) : super(uuid, fields: [
          name,
          organisation,
          suffix,
          departments,
          active,
        ]);

  /// Division name
  final String name;

  /// FleetMap number suffix
  final String suffix;

  /// List of [Department.uuid]s
  final List<String> departments;

  /// Reference to division parent
  final AggregateRef<Organisation> organisation;

  /// Division status
  final bool active;

  /// Get [Division] reference
  AggregateRef<Division> toRef();
}
