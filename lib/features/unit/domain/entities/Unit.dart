

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/utils/data.dart';

abstract class Unit extends Trackable<Map<String, dynamic>> {
  Unit({
    required String uuid,
    required this.type,
    required this.number,
    required this.status,
    required this.callsign,
    this.phone,
    this.operation,
    AggregateRef<Tracking>? tracking,
    List<String>? personnels = const <String>[],
  })  : personnels = personnels ?? const <String>[],
        super(uuid, tracking!, fields: [
          type,
          number,
          status,
          callsign,
          phone,
          personnels ?? const <String>[],
        ]);

  final int? number;
  final UnitType? type;
  final UnitStatus? status;
  final String? phone;
  final String? callsign;
  final List<String> personnels;
  final AggregateRef<Operation>? operation;

  String get name => "${translateUnitType(type)} $number";

  /// Get searchable string
  get searchable => props
      .map((prop) =>
          prop is UnitType ? translateUnitType(prop) : (prop is UnitStatus ? translateUnitStatus(prop) : prop))
      .join(' ');

  /// Clone with json
  Unit mergeWith(Map<String, dynamic> json);

  Unit copyWith({
    String? uuid,
    UnitType? type,
    int? number,
    UnitStatus? status,
    String? phone,
    String? callsign,
    List<String>? personnels,
    AggregateRef<Tracking>? tracking,
    AggregateRef<Operation>? operation,
  });
}

enum UnitStatus { mobilized, deployed, retired }

String translateUnitStatus(UnitStatus? status) {
  switch (status) {
    case UnitStatus.mobilized:
      return "Mobilisert";
    case UnitStatus.deployed:
      return "Deployert";
    case UnitStatus.retired:
      return "Oppløst";
    default:
      return enumName(status);
  }
}

enum UnitType { team, k9, boat, vehicle, snowmobile, atv, commandpost, other }

String translateUnitType(UnitType? type) {
  switch (type) {
    case UnitType.team:
      return "Lag";
    case UnitType.k9:
      return "Hund";
    case UnitType.vehicle:
      return "Kjøretøy";
    case UnitType.boat:
      return "Båt";
    case UnitType.snowmobile:
      return "Snøskuter";
    case UnitType.other:
      return "Annet";
    case UnitType.commandpost:
      return "KO";
    default:
      return enumName(type);
  }
}
