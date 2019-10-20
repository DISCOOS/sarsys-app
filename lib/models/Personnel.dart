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
  final Affiliation affiliation;
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
    this.affiliation,
    this.tracking,
  }) : super([
          id,
          userId,
          fname,
          lname,
          affiliation,
          tracking,
        ]);

  /// Get searchable string
  get searchable => props.map((prop) => prop is PersonnelStatus ? translatePersonnelStatus(prop) : prop).join(' ');

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
      affiliation: clone.affiliation,
      tracking: clone.tracking,
    );
  }

  Personnel cloneWith({
    String id,
    String userId,
    PersonnelStatus status,
    String fname,
    String lname,
    Affiliation affiliation,
    String tracking,
  }) {
    return Personnel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      affiliation: affiliation ?? this.affiliation,
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
