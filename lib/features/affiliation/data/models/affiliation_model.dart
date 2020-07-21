import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/models/converters.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/models/AggregateRef.dart';

part 'affiliation_model.g.dart';

@JsonSerializable()
class AffiliationModel extends Affiliation {
  AffiliationModel({
    String uuid,
    this.div,
    this.dep,
    this.org,
    this.person,
    bool active,
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
  @JsonKey(fromJson: toOrgRef)
  final AggregateRef<OrganisationModel> org;

  @override
  @JsonKey(fromJson: toDivRef)
  final AggregateRef<DivisionModel> div;

  @override
  @JsonKey(fromJson: toDepRef)
  final AggregateRef<DepartmentModel> dep;

  @override
  @JsonKey(fromJson: toPersonRef)
  final AggregateRef<PersonModel> person;

  /// Factory constructor for creating a new `Affiliation` instance
  factory AffiliationModel.fromJson(Map<String, dynamic> json) => _$AffiliationModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AffiliationModelToJson(this);

  @override
  Affiliation copyWith({
    String uuid,
    bool active,
    AffiliationType type,
    AggregateRef<Division> div,
    AggregateRef<Person> person,
    AggregateRef<Department> dep,
    AggregateRef<Organisation> org,
    AffiliationStandbyStatus status,
  }) =>
      AffiliationModel(
        uuid: uuid ?? this.uuid,
        type: type ?? this.type,
        status: status ?? this.status,
        active: active ?? this.active,
        div: div?.cast<DivisionModel>() ?? this.div,
        dep: dep?.cast<DepartmentModel>() ?? this.dep,
        org: org?.cast<OrganisationModel>() ?? this.org,
        person: person?.cast<PersonModel>() ?? this.person,
      );

  @override
  AggregateRef<AffiliationModel> toRef() => uuid != null ? AggregateRef.fromType<AffiliationModel>(uuid) : null;
}
