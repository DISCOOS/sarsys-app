import 'package:meta/meta.dart';

import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/utils/data_utils.dart';

abstract class Unit extends Trackable<Map<String, dynamic>> {
  Unit({
    @required String uuid,
    @required this.type,
    @required this.number,
    @required this.status,
    @required this.callsign,
    this.phone,
    this.personnels = const [],
    AggregateRef<Tracking> tracking,
  }) : super(uuid, tracking, fields: [
          type,
          number,
          status,
          callsign,
          phone,
          personnels,
        ]);

  final int number;
  final UnitType type;
  final UnitStatus status;
  final String phone;
  final String callsign;
  final List<Personnel> personnels;

  String get name => "${translateUnitType(type)} $number";

  /// Get searchable string
  get searchable => props
      .map((prop) =>
          prop is UnitType ? translateUnitType(prop) : (prop is UnitStatus ? translateUnitStatus(prop) : prop))
      .join(' ');

  /// Clone with json
  Unit mergeWith(Map<String, dynamic> json);

  Unit copyWith({
    String uuid,
    UnitType type,
    int number,
    UnitStatus status,
    String phone,
    String callsign,
    List<Personnel> personnels,
    AggregateRef<Tracking> tracking,
  });
}

enum UnitStatus { Mobilized, Deployed, Retired }

String translateUnitStatus(UnitStatus status) {
  switch (status) {
    case UnitStatus.Mobilized:
      return "Mobilisert";
    case UnitStatus.Deployed:
      return "Deployert";
    case UnitStatus.Retired:
      return "Oppløst";
    default:
      return enumName(status);
  }
}

enum UnitType { Team, K9, Boat, Vehicle, Snowmobile, ATV, CommandPost, Other }

String translateUnitType(UnitType type) {
  switch (type) {
    case UnitType.Team:
      return "Lag";
    case UnitType.K9:
      return "Hund";
    case UnitType.Vehicle:
      return "Kjøretøy";
    case UnitType.Boat:
      return "Båt";
    case UnitType.Snowmobile:
      return "Snøskuter";
    case UnitType.Other:
      return "Annet";
    case UnitType.CommandPost:
      return "KO";
    default:
      return enumName(type);
  }
}
