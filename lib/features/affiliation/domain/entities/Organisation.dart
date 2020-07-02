import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/models/core.dart';
import 'package:meta/meta.dart';

import 'FleetMap.dart';

abstract class Organisation extends Aggregate<Map<String, dynamic>> {
  /// Organisation name
  final String name;

  /// FleetMap prefix number
  final String prefix;

  /// Organisation FleetMap
  final FleetMap fleetMap;

  /// List of [Division.uuid]s
  final List<String> divisions;

  /// Organisation status
  final bool active;

  Organisation({
    @required String uuid,
    @required this.name,
    @required this.prefix,
    @required this.fleetMap,
    @required this.divisions,
    @required this.active,
  }) : super(uuid, fields: [
          name,
          prefix,
          fleetMap,
          divisions,
          active,
        ]);
}
