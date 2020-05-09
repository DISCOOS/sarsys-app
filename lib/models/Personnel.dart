import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/utils/data_utils.dart';

import 'Affiliation.dart';
import 'AggregateRef.dart';
import 'converters.dart';
import 'Tracking.dart';
import 'Unit.dart';

part 'Personnel.g.dart';

@JsonSerializable()
class Personnel extends Trackable<Map<String, dynamic>> {
  Personnel({
    @required String uuid,
    @required this.userId,
    this.status,
    this.fname,
    this.lname,
    this.phone,
    this.affiliation,
    this.function,
    this.unit,
    AggregateRef<Tracking> tracking,
  }) : super(uuid, tracking, fields: [
          userId,
          status,
          fname,
          lname,
          phone,
          affiliation,
          function,
          unit,
        ]);

  final String userId;
  final PersonnelStatus status;
  final String fname;
  final String lname;
  final String phone;
  final Affiliation affiliation;
  final OperationalFunction function;
  @JsonKey(
    fromJson: toUnitRef,
    nullable: true,
    includeIfNull: false,
  )
  final AggregateRef<Unit> unit;

  String get name => "${fname ?? ''} ${lname ?? ''}";
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

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
      uuid: clone.uuid,
      userId: clone.userId,
      status: clone.status,
      fname: clone.fname,
      lname: clone.lname,
      phone: clone.phone,
      unit: clone.unit,
      function: clone.function,
      tracking: clone.tracking,
      affiliation: clone.affiliation,
    );
  }

  Personnel cloneWith({
    String uuid,
    String userId,
    String fname,
    String lname,
    String phone,
    PersonnelStatus status,
    Affiliation affiliation,
    AggregateRef<Unit> unit,
    OperationalFunction function,
    AggregateRef<Tracking> tracking,
  }) {
    return Personnel(
      uuid: uuid ?? this.uuid,
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      phone: phone ?? this.phone,
      unit: unit ?? this.unit,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      function: function ?? this.function,
      tracking: tracking ?? this.tracking,
      affiliation: affiliation ?? this.affiliation,
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
