import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'personnel_model.g.dart';

@JsonSerializable()
class PersonnelModel extends Personnel implements JsonObject<Map<String, dynamic>> {
  PersonnelModel({
    @required String uuid,
    @required this.person,
    @required AggregateRef<Tracking> tracking,
    @required AggregateRef<Operation> operation,
    @required AggregateRef<Affiliation> affiliation,
    PersonnelStatus status,
    AggregateRef<Unit> unit,
    OperationalFunctionType function,
  })  : unit = unit?.cast<UnitModel>(),
        tracking = tracking?.cast<TrackingModel>(),
        operation = operation?.cast<OperationModel>(),
        affiliation = affiliation?.cast<AffiliationModel>(),
        super(
          uuid: uuid,
          unit: unit,
          person: person,
          status: status,
          tracking: tracking,
          function: function,
          operation: operation,
          affiliation: affiliation,
        );

  @override
  final PersonModel person;

  @override
  @JsonKey(fromJson: toUnitRef)
  final AggregateRef<UnitModel> unit;

  @override
  @JsonKey(fromJson: toOperationRef)
  final AggregateRef<OperationModel> operation;

  @override
  @JsonKey(fromJson: toTrackingRef)
  final AggregateRef<TrackingModel> tracking;

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
      operation: clone.operation,
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
    AggregateRef<Operation> operation,
    AggregateRef<Affiliation> affiliation,
  }) {
    return PersonnelModel(
      uuid: uuid ?? this.uuid,
      person: _copyPerson(
        person?.uuid,
        fname,
        lname,
        phone,
        email,
        userId,
        person?.temporary,
      ),
      status: status ?? this.status,
      function: function ?? this.function,
      unit: unit?.cast<UnitModel>() ?? this.unit,
      tracking: tracking?.cast<TrackingModel>() ?? this.tracking,
      operation: operation?.cast<OperationModel>() ?? this.operation,
      affiliation: affiliation?.cast<AffiliationModel>() ?? this.affiliation,
    );
  }

  Person _copyPerson(
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool temporary,
  ) {
    return (person ?? PersonModel(uuid: uuid)).copyWith(
      uuid: uuid ?? person?.uuid,
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      temporary: temporary ?? this.person?.temporary,
    );
  }

  @override
  Personnel withPerson(Person person, {bool keep = true}) {
    return PersonnelModel(
      uuid: this.uuid,
      unit: unit,
      status: status,
      function: function,
      tracking: tracking,
      operation: operation,
      affiliation: affiliation,
      person: person != null
          ? _copyPerson(
              person.uuid,
              person.fname,
              person.lname,
              person.phone,
              person.email,
              person.userId,
              person.temporary,
            )
          : keep
              ? this.person
              : null,
    );
  }
}
