

import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/utils/data.dart';

abstract class Personnel extends Trackable<Map<String, dynamic>> with Affiliate {
  Personnel({
    required String uuid,
    this.unit,
    this.status,
    this.function,
    this.operation,
    required this.affiliation,
    required AggregateRef<Tracking> tracking,
  }) : super(uuid, tracking, fields: [
          unit,
          status,
          function,
          affiliation,
        ]) {
    assert(affiliation.person !=null, "Person can not be null");
  }

  String? get fname => person.fname;
  String? get lname => person.lname;
  String? get phone => person.phone;
  String? get email => person.email;
  String? get userId => person.userId;
  Person get person => affiliation.person!;

  final PersonnelStatus? status;
  final Affiliation affiliation;
  final AggregateRef<Unit>? unit;
  final OperationalFunctionType? function;
  final AggregateRef<Operation>? operation;

  String get name => emptyAsNull("${fname ?? ''} ${lname ?? ''}".trim()) ?? 'Mannskap';
  String get formal => "${fname?.substring(0, 1).toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1).toUpperCase() ?? ''}${lname?.substring(0, 1).toUpperCase() ?? ''}";

  /// Check if personnel is mobilized
  bool get isMobilized => !const [
        PersonnelStatus.leaving,
        PersonnelStatus.retired,
      ].contains(status);

  /// Get searchable string
  String get searchable => props
      .map((prop) => prop is PersonnelStatus ? translatePersonnelStatus(prop) : prop)
      .map((prop) => prop is OperationalFunctionType ? translateOperationalFunction(prop) : prop)
      .join(' ');

  bool get isAvailable => !isUnavailable;
  bool get isUnavailable => const [PersonnelStatus.leaving, PersonnelStatus.retired].contains(status);

  /// Clone with json
  Personnel mergeWith(Map<String, dynamic> json);

  Personnel copyWith({
    String? uuid,
    String? fname,
    String? lname,
    String? phone,
    String? email,
    String? userId,
    bool? temporary,
    PersonnelStatus? status,
    AggregateRef<Unit>? unit,
    Affiliation affiliation,
    OperationalFunctionType? function,
    AggregateRef<Tracking>? tracking,
    AggregateRef<Operation>? operation,
  });

  Personnel withPerson(Person person, {bool keep = true});
}

enum PersonnelStatus { alerted, enroute, onscene, leaving, retired }

String translatePersonnelStatus(PersonnelStatus? status) {
  switch (status) {
    case PersonnelStatus.alerted:
      return "Varslet";
    case PersonnelStatus.enroute:
      return "På vei til";
    case PersonnelStatus.onscene:
      return "Ankommet";
    case PersonnelStatus.leaving:
      return "På vei hjem";
    case PersonnelStatus.retired:
      return "Dimittert";
    default:
      return enumName(status);
  }
}

enum OperationalFunctionType { personnel, unit_leader, commander }

String translateOperationalFunction(OperationalFunctionType? function) {
  switch (function ?? OperationalFunctionType.personnel) {
    case OperationalFunctionType.commander:
      return "Aksjonsleder";
    case OperationalFunctionType.unit_leader:
      return "Lagleder";
    case OperationalFunctionType.personnel:
      return "Mannskap";
    default:
      return enumName(function);
  }
}

IconData toPersonnelStatusIcon(PersonnelStatus? status) {
  switch (status) {
    case PersonnelStatus.alerted:
      return Icons.warning;
    case PersonnelStatus.enroute:
      return Icons.directions_run;
    case PersonnelStatus.onscene:
      return Icons.assignment_turned_in;
    case PersonnelStatus.leaving:
      return Icons.directions_walk;
    case PersonnelStatus.retired:
    default:
      return Icons.home;
  }
}
