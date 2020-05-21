import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'converters.dart';

part 'Unit.g.dart';

@JsonSerializable(
  explicitToJson: true,
  anyMap: true,
)
class Unit extends Trackable<Map<String, dynamic>> {
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

  /// Factory constructor for creating a new `Unit` instance from json data
  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitToJson(this);

  /// Clone with json
  Unit withJson(Map<String, dynamic> json) {
    var clone = Unit.fromJson(json);
    return cloneWith(
      uuid: clone.uuid,
      type: clone.type,
      number: clone.number,
      status: clone.status,
      phone: clone.phone,
      callsign: clone.callsign,
      tracking: clone.tracking,
      personnels: clone.personnels ?? const [],
    );
  }

  Unit cloneWith({
    String uuid,
    UnitType type,
    int number,
    UnitStatus status,
    String phone,
    String callsign,
    List<Personnel> personnels,
    AggregateRef<Tracking> tracking,
  }) {
    return Unit(
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      number: number ?? this.number,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      callsign: callsign ?? this.callsign,
      tracking: tracking ?? this.tracking,
      personnels: personnels ?? this.personnels ?? const [],
    );
  }
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
