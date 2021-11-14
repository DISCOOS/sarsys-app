

import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';

import 'Department.dart';
import 'Division.dart';
import 'Organisation.dart';
import 'Person.dart';

mixin Affiliate {
  Affiliation get affiliation;
}

abstract class Affiliation extends Aggregate<Map<String, dynamic>> {
  Affiliation({
    String? uuid,
    this.person,
    this.org,
    this.div,
    this.dep,
    this.type,
    this.status,
    this.active,
  }) : super(uuid!, fields: [
          person,
          org,
          div,
          dep,
          type,
          status,
          active,
        ]);

  final Person? person;
  final AggregateRef<Organisation>? org;
  final AggregateRef<Division>? div;
  final AggregateRef<Department>? dep;
  final AffiliationType? type;
  final AffiliationStandbyStatus? status;
  final bool? active;

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

  /// Check if person is organized
  bool get isOrganized => !isUnorganized;

  /// Check if person is unorganized
  bool get isUnorganized => (isEmpty || isAffiliate) && !(isOrg || isDiv || isDep);

  /// Check if affiliation is empty
  bool get isEmpty => !(isAffiliate || isEntity);

  /// Get searchable string
  String get searchable => props
      .where((prop) => prop is! AggregateRef)
      .map((prop) => prop is AffiliationStandbyStatus ? translateAffiliationStandbyStatus(prop) : prop)
      .map((prop) => prop is AffiliationType ? translateAffiliationType(prop) : prop)
      .join(' ');

  /// Get Aggregate reference
  AggregateRef<Affiliation>? toRef();

  Affiliation copyWith({
    String? uuid,
    bool? active,
    Person person,
    AffiliationType? type,
    AggregateRef<Division>? div,
    AggregateRef<Department>? dep,
    AggregateRef<Organisation>? org,
    AffiliationStandbyStatus? status,
  });

  Affiliation withPerson(Person person, {bool keep = true});
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

String translateAffiliationStandbyStatus(AffiliationStandbyStatus? status) {
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
