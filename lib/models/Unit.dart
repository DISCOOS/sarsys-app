import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Unit.g.dart';

@JsonSerializable()
class Unit extends Equatable {
  final String id;
  final int number;
  final UnitType type;
  final UnitStatus status;
  final String phone;
  final String callsign;
  final String tracking;

  String get name => "${translateUnitType(type)} $number";

  Unit({
    @required this.id,
    @required this.type,
    @required this.number,
    @required this.status,
    @required this.callsign,
    this.phone,
    this.tracking,
  }) : super([id, type, number, status, phone, callsign, tracking]);

  /// Factory constructor for creating a new `Unit` instance
  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitToJson(this);

  /// Clone with json
  Unit withJson(Map<String, dynamic> json) {
    var clone = Unit.fromJson(json);
    return cloneWith(
      id: clone.id,
      type: clone.type,
      number: clone.number,
      status: clone.status,
      phone: clone.phone,
      callsign: clone.callsign,
      tracking: clone.tracking,
    );
  }

  Unit cloneWith({
    String id,
    UnitType type,
    int number,
    UnitStatus status,
    String phone,
    String callsign,
    String tracking,
  }) {
    return Unit(
      id: id ?? this.id,
      type: type ?? this.type,
      number: number ?? this.number,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      callsign: callsign ?? this.callsign,
      tracking: tracking ?? this.tracking,
    );
  }
}

enum UnitStatus { Mobilized, Deployed, Retired }

enum UnitType { Team, K9, Boat, Vehicle, Snowmobile, ATV, Other }

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
      return "Snøscooter";
    case UnitType.Other:
      return "Annet";
    default:
      return enumName(type);
  }
}

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
