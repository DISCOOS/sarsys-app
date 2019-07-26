import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Unit.g.dart';

@JsonSerializable()
class Unit extends Equatable {
  final String id;
  final UnitType type;
  final UnitStatus status;
  final String name;
  final String tracking;

  Unit({
    @required this.id,
    @required this.type,
    @required this.status,
    @required this.name,
    this.tracking,
  }) : super([id, type, name, tracking]);

  /// Factory constructor for creating a new `Unit` instance
  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitToJson(this);

  /// Clone with json
  Unit withJson(Map<String, dynamic> json) {
    var clone = Unit.fromJson(json);
    return cloneWith(
      id: clone.id,
      name: clone.name,
      type: clone.type,
      status: clone.status,
      tracking: clone.tracking,
    );
  }

  Unit cloneWith({
    String id,
    UnitType type,
    UnitStatus status,
    String name,
    String tracking,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      tracking: tracking ?? this.tracking,
    );
  }
}

enum UnitStatus { Mobilized, Deployed, Paused, Retired }

enum UnitType { Team, K9, Boat, Vehicle, Snowmobile, ATV, Other }

String translateUnitType(UnitType type) {
  switch (type) {
    case UnitType.Team:
      return "Lag";
    case UnitType.K9:
      return "Hund";
    case UnitType.Vehicle:
      return "Kjøretøy";
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
    case UnitStatus.Paused:
      return "Pauset";
    case UnitStatus.Retired:
      return "Oppløst";
    default:
      return enumName(status);
  }
}
