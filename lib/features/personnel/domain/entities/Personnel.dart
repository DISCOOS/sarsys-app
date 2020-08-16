import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/utils/data.dart';

abstract class Personnel extends Trackable<Map<String, dynamic>> with Affiliate {
  Personnel({
    @required String uuid,
    this.unit,
    this.person,
    this.status,
    this.function,
    this.affiliation,
    AggregateRef<Tracking> tracking,
  }) : super(uuid, tracking, fields: [
          unit,
          person,
          status,
          function,
          affiliation,
        ]);

  String get fname => person?.fname;
  String get lname => person?.lname;
  String get phone => person?.phone;
  String get email => person?.email;
  String get userId => person?.userId;

  final Person person;
  final PersonnelStatus status;
  final AggregateRef<Unit> unit;
  final OperationalFunctionType function;
  final AggregateRef<Affiliation> affiliation;

  String get name => "${fname ?? ''} ${lname ?? ''}";
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

  /// Get searchable string
  String get searchable => props
      .map((prop) => prop is PersonnelStatus ? translatePersonnelStatus(prop) : prop)
      .map((prop) => prop is OperationalFunctionType ? translateOperationalFunction(prop) : prop)
      .join(' ');

  /// Clone with json
  Personnel mergeWith(Map<String, dynamic> json);

  Personnel copyWith({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    PersonnelStatus status,
    AggregateRef<Unit> unit,
    OperationalFunctionType function,
    AggregateRef<Tracking> tracking,
    AggregateRef<Affiliation> affiliation,
  });

  Personnel withPerson(Person person);
}

enum PersonnelStatus { alerted, enroute, onscene, leaving, retired }

String translatePersonnelStatus(PersonnelStatus status) {
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

String translateOperationalFunction(OperationalFunctionType function) {
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

IconData toPersonnelStatusIcon(PersonnelStatus status) {
  switch (status) {
    case PersonnelStatus.alerted:
      return Icons.warning;
    case PersonnelStatus.enroute:
      return Icons.directions_run;
    case PersonnelStatus.onscene:
      return Icons.playlist_add_check;
    case PersonnelStatus.leaving:
      return Icons.directions_walk;
    case PersonnelStatus.retired:
    default:
      return Icons.home;
  }
}
