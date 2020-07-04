import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/core.dart';

import 'Department.dart';
import 'Division.dart';
import 'Organisation.dart';
import 'Person.dart';

mixin Affiliate {
  AggregateRef<Affiliation> affiliation;
}

abstract class Affiliation extends Aggregate<Map<String, dynamic>> {
  Affiliation({
    String uuid,
    @required this.person,
    @required this.org,
    @required this.div,
    @required this.dep,
    @required this.type,
    @required this.status,
    @required this.active,
  }) : super(uuid, fields: [
          person,
          org,
          div,
          dep,
          type,
          status,
          active,
        ]);

  final AggregateRef<Person> person;
  final AggregateRef<Organisation> org;
  final AggregateRef<Division> div;
  final AggregateRef<Department> dep;
  final AffiliationType type;
  final AffiliationStandbyStatus status;
  final bool active;

  /// Check if is [Department]
  bool get isDep => dep?.uuid != null;

  /// Check if is [Division]
  bool get isDiv => div?.uuid != null && !isDep;

  /// Check if is [Organisation]
  bool get isOrg => org?.uuid != null && !(isDiv || isDep);

  /// Check if an Organisation, Division or Department
  bool get isEntity => !isAffiliate && (isOrg || isDiv || isDep);

  /// Check if person
  bool get isAffiliate => person?.uuid != null;

  /// Check if person is unorganized
  bool get isUnorganized => isAffiliate && !(isOrg || isDiv || isDep);

  /// Check if affiliation is empty
  bool get isEmpty => !(isAffiliate || isEntity);

  /// Check if affiliation with person is temporary
  bool get isTemporary => isEmpty || isUnorganized;

  /// Get Aggregate reference
  AggregateRef<Affiliation> toRef();

  Affiliation copyWith({
    String uuid,
    bool active,
    AffiliationType type,
    AggregateRef<Division> div,
    AggregateRef<Person> person,
    AggregateRef<Department> dep,
    AggregateRef<Organisation> org,
    AffiliationStandbyStatus status,
  });
}

enum AffiliationType {
  /// Member of the organisation
  member,

  /// Employee of the organisation
  employee,

  /// External to the organisation
  external,

  /// Volunteer, but not a member of organisation
  volunteer,
}

String translateAffiliationType(AffiliationType type) {
  switch (type) {
    case AffiliationType.member:
      return "Medlem";
    case AffiliationType.employee:
      return "Ansatt";
    case AffiliationType.external:
      return "Ekstern";
    case AffiliationType.volunteer:
      return "Frivillig";
    default:
      return enumName(type);
  }
}

enum AffiliationStandbyStatus {
  /// Readily available for mobilization
  available,

  /// Employee of the organisation
  short_notice,

  /// Not available for mobilization
  unavailable,
}

String translateAffiliationStandbyStatus(AffiliationStandbyStatus status) {
  switch (status) {
    case AffiliationStandbyStatus.available:
      return "Tilgjengelig";
    case AffiliationStandbyStatus.short_notice:
      return "Kort varsel";
    case AffiliationStandbyStatus.unavailable:
      return "Ikke tilgjengelig";
    default:
      return enumName(status);
  }
}
