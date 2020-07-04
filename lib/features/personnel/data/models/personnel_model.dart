import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
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
    @required this.affiliation,
    this.unit,
    this.person,
    PersonnelStatus status,
    OperationalFunctionType function,
    AggregateRef<Tracking> tracking,
  }) : super(
          uuid: uuid,
          unit: unit,
          person: person,
          status: status,
          tracking: tracking,
          function: function,
          affiliation: affiliation,
        );

  @override
  final PersonModel person;

  @override
  @JsonKey(fromJson: toUnitRef)
  final AggregateRef<UnitModel> unit;

  @override
  @JsonKey(fromJson: toAffiliationRef)
  final AggregateRef<AffiliationModel> affiliation;

  /// Factory constructor for creating a new `Personnel` instance from json data
  factory PersonnelModel.fromJson(Map<String, dynamic> json) => _$PersonnelModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PersonnelModelToJson(this);

  /// Clone with json
  Personnel mergeWith(Map<String, dynamic> json) {
    var clone = PersonnelModel.fromJson(json);
    return copyWith(
      uuid: clone.uuid,
      unit: clone.unit,
      fname: clone.fname,
      lname: clone.lname,
      phone: clone.phone,
      email: clone.email,
      userId: clone.userId,
      status: clone.status,
      function: clone.function,
      tracking: clone.tracking,
      affiliation: clone.affiliation,
    );
  }

  Personnel copyWith({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    PersonnelStatus status,
    AggregateRef<Unit> unit,
    AggregateRef<Tracking> tracking,
    OperationalFunctionType function,
    AggregateRef<Affiliation> affiliation,
  }) {
    return PersonnelModel(
      uuid: uuid ?? this.uuid,
      unit: unit?.cast<UnitModel>() ?? this.unit,
      person: _copyPerson(fname, lname, phone, email, userId),
      status: status ?? this.status,
      function: function ?? this.function,
      tracking: tracking ?? this.tracking,
      affiliation: affiliation?.cast<AffiliationModel>() ?? this.affiliation,
    );
  }

  Person _copyPerson(
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
  ) {
    return (person ?? PersonModel(uuid: null)).copyWith(
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      userId: userId ?? this.userId,
    );
  }
}
