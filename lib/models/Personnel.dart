import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Personnel.g.dart';

@JsonSerializable()
class Personnel extends Equatable {
  final String id;
  final String userId;
  final PersonnelStatus status;
  final String fname;
  final String lname;
  final String phone;
  final Affiliation affiliation;
  final OperationalFunction function;
  final String tracking;

  String get name => "${fname ?? ''} ${lname ?? ''}";
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

  Personnel({
    @required this.id,
    @required this.userId,
    this.status,
    this.fname,
    this.lname,
    this.phone,
    this.affiliation,
    this.function,
    this.tracking,
  }) : super([
          id,
          userId,
          status,
          fname,
          lname,
          phone,
          affiliation,
          function,
          tracking,
        ]);

  /// Get searchable string
  get searchable => props
      .map((prop) => prop is PersonnelStatus ? translatePersonnelStatus(prop) : prop)
      .map((prop) => prop is OperationalFunction ? translateOperationalFunction(prop) : prop)
      .join(' ');

  /// Factory constructor for creating a new `Personnel` instance from json data
  factory Personnel.fromJson(Map<String, dynamic> json) => _$PersonnelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PersonnelToJson(this);

  /// Clone with json
  Personnel withJson(Map<String, dynamic> json) {
    var clone = Personnel.fromJson(json);
    return cloneWith(
      id: clone.id,
      userId: clone.userId,
      status: clone.status,
      fname: clone.fname,
      lname: clone.lname,
      phone: clone.phone,
      affiliation: clone.affiliation,
      function: clone.function,
      tracking: clone.tracking,
    );
  }

  Personnel cloneWith({
    String id,
    String userId,
    PersonnelStatus status,
    String fname,
    String lname,
    String phone,
    Affiliation affiliation,
    OperationalFunction function,
    String tracking,
  }) {
    return Personnel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      phone: phone ?? this.phone,
      affiliation: affiliation ?? this.affiliation,
      function: function ?? this.function,
      tracking: tracking ?? this.tracking,
    );
  }
}

enum PersonnelStatus { Mobilized, OnScene, Retired }

String translatePersonnelStatus(PersonnelStatus status) {
  switch (status) {
    case PersonnelStatus.Mobilized:
      return "Mobilisert";
    case PersonnelStatus.OnScene:
      return "Ankommet";
    case PersonnelStatus.Retired:
      return "Dimittert";
    default:
      return enumName(status);
  }
}

enum OperationalFunction { Commander, UnitLeader, Personnel }

String translateOperationalFunction(OperationalFunction function) {
  switch (function) {
    case OperationalFunction.Commander:
      return "Aksjonsleder";
    case OperationalFunction.UnitLeader:
      return "Lagleder";
    case OperationalFunction.Personnel:
    default:
      return "Mannskap";
  }
}
