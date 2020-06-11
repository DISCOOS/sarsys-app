import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/models/converters.dart';
import 'package:SarSys/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'personnel_model.g.dart';

@JsonSerializable()
class PersonnelModel extends Personnel implements JsonObject<Map<String, dynamic>> {
  PersonnelModel({
    @required String uuid,
    @required String userId,
    PersonnelStatus status,
    String fname,
    String lname,
    String phone,
    Affiliation affiliation,
    OperationalFunction function,
    this.unit,
    AggregateRef<Tracking> tracking,
  }) : super(
          uuid: uuid,
          tracking: tracking,
          userId: userId,
          status: status,
          fname: fname,
          lname: lname,
          phone: phone,
          affiliation: affiliation,
          function: function,
          unit: unit,
        );

  @override
  @JsonKey(fromJson: toUnitRef)
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
  factory PersonnelModel.fromJson(Map<String, dynamic> json) => _$PersonnelModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PersonnelModelToJson(this);

  /// Clone with json
  Personnel mergeWith(Map<String, dynamic> json) {
    var clone = PersonnelModel.fromJson(json);
    return copyWith(
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

  Personnel copyWith({
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
    return PersonnelModel(
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
