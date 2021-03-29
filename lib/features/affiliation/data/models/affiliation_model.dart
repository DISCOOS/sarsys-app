import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/core/domain/models/AggregateRef.dart';

part 'affiliation_model.g.dart';

@JsonSerializable()
class AffiliationModel extends Affiliation {
  AffiliationModel({
    String uuid,
    this.div,
    this.dep,
    this.org,
    bool active,
    this.person,
    AffiliationType type,
    AffiliationStandbyStatus status,
  }) : super(
          uuid: uuid,
          person: person,
          org: org,
          div: div,
          dep: dep,
          type: type,
          status: status,
          active: active,
        );

  @override
  List<Object> get props => [
        uuid,
        person,
        org,
        div,
        dep,
        type,
        status,
        active,
      ];

  @override
  @JsonKey(
    // Person is read only with 'expand=person'
    toJson: fromPersonRef,
  )
  final PersonModel person;
  static dynamic fromPersonRef(Person person) => person.toRef().toJson();

  @override
  @JsonKey(fromJson: toOrgRef)
  final AggregateRef<OrganisationModel> org;

  @override
  @JsonKey(fromJson: toDivRef)
  final AggregateRef<DivisionModel> div;

  @override
  @JsonKey(fromJson: toDepRef)
  final AggregateRef<DepartmentModel> dep;

  /// Factory constructor for creating a new `Affiliation` instance
  factory AffiliationModel.fromJson(Map<String, dynamic> json) => _$AffiliationModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AffiliationModelToJson(this);

  @override
  Affiliation copyWith({
    String uuid,
    bool active,
    Person person,
    AffiliationType type,
    AggregateRef<Division> div,
    AggregateRef<Department> dep,
    AggregateRef<Organisation> org,
    AffiliationStandbyStatus status,
  }) =>
      AffiliationModel(
        uuid: uuid ?? this.uuid,
        type: type ?? this.type,
        status: status ?? this.status,
        active: active ?? this.active,
        person: person ?? this.person,
        div: div?.cast<DivisionModel>() ?? this.div,
        dep: dep?.cast<DepartmentModel>() ?? this.dep,
        org: org?.cast<OrganisationModel>() ?? this.org,
      );

  @override
  Affiliation withPerson(Person person, {bool keep = true}) {
    return AffiliationModel(
      div: div,
      dep: dep,
      org: org,
      uuid: uuid,
      type: type,
      status: status,
      active: active,
      person: person ?? (keep ? this.person : null),
    );
  }

  @override
  AggregateRef<AffiliationModel> toRef() => uuid != null ? AggregateRef.fromType<AffiliationModel>(uuid) : null;
}
