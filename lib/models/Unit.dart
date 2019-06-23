import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Unit.g.dart';

@JsonSerializable()
class Unit extends Equatable {
  final String id;
  final UnitType type;
  final String name;
  final String tracking;

  Unit({
    @required this.id,
    @required this.type,
    @required this.name,
    this.tracking,
  }) : super([id, type, name, tracking]);

  /// Factory constructor for creating a new `Unit` instance
  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitToJson(this);
}

enum UnitType { Team, K9, Boat, Vehicle, Snowmobile, ATV, Other }

String translateDeviceType(UnitType type) {
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
