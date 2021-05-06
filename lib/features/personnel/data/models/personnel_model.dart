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
    @required this.affiliation,
    @required AggregateRef<Tracking> tracking,
    @required AggregateRef<Operation> operation,
    PersonnelStatus status,
    AggregateRef<Unit> unit,
    OperationalFunctionType function,
  })  : unit = unit?.cast<UnitModel>(),
        tracking = tracking?.cast<TrackingModel>(),
        operation = operation?.cast<OperationModel>(),
        super(
          uuid: uuid,
          unit: unit,
          status: status,
          tracking: tracking,
          function: function,
          operation: operation,
          affiliation: affiliation,
        );

  @override
  PersonModel get person => affiliation.person;

  @override
  final AffiliationModel affiliation;

  @override
  @JsonKey(fromJson: toUnitRef)
  final AggregateRef<UnitModel> unit;

  @override
  @JsonKey(fromJson: toOperationRef)
  final AggregateRef<OperationModel> operation;

  @override
  @JsonKey(fromJson: toTrackingRef)
  final AggregateRef<TrackingModel> tracking;

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
    bool temporary,
    PersonnelStatus status,
    Affiliation affiliation,
    AggregateRef<Unit> unit,
    AggregateRef<Tracking> tracking,
    OperationalFunctionType function,
    AggregateRef<Operation> operation,
  }) {
    final _affiliation = (affiliation ?? this.affiliation);
    final _person = _affiliation.person;
    return PersonnelModel(
      uuid: uuid ?? this.uuid,
      status: status ?? this.status,
      function: function ?? this.function,
      unit: unit?.cast<UnitModel>() ?? this.unit,
      affiliation: _affiliation.copyWith(
        person: _copyPerson(
          fname: fname,
          lname: lname,
          phone: phone,
          email: email,
          userId: userId,
          person: _person,
          temporary: temporary,
        ),
      ),
      tracking: tracking?.cast<TrackingModel>() ?? this.tracking,
      operation: operation?.cast<OperationModel>() ?? this.operation,
    );
  }

  Person _copyPerson({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    Person person,
    bool temporary,
  }) {
    final _person = person ?? this.person;
    return person?.copyWith(
      uuid: uuid ?? _person?.uuid,
      fname: fname ?? _person?.fname,
      lname: lname ?? _person?.lname,
      phone: phone ?? _person?.phone,
      email: email ?? _person?.email,
      userId: userId ?? _person?.userId,
      temporary: temporary ?? _person?.temporary,
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
      affiliation: affiliation.copyWith(
        person: person != null
            ? _copyPerson(
                person: person,
              )
            : keep
                ? this.person
                : null,
      ),
    );
  }
}
