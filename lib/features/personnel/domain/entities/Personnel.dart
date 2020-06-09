import 'package:meta/meta.dart';

import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';

abstract class Personnel extends Trackable<Map<String, dynamic>> {
  Personnel({
    @required String uuid,
    @required this.userId,
    this.status,
    this.fname,
    this.lname,
    this.phone,
    this.affiliation,
    this.function,
    this.unit,
    AggregateRef<Tracking> tracking,
  }) : super(uuid, tracking, fields: [
          userId,
          status,
          fname,
          lname,
          phone,
          affiliation,
          function,
          unit,
        ]);

  final String userId;
  final PersonnelStatus status;
  final String fname;
  final String lname;
  final String phone;
  final Affiliation affiliation;
  final OperationalFunction function;
  final AggregateRef<Unit> unit;

  String get name => "${fname ?? ''} ${lname ?? ''}";
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

  /// Get searchable string
  get searchable => props
      .map((prop) => prop is PersonnelStatus ? translatePersonnelStatus(prop) : prop)
      .map((prop) => prop is OperationalFunction ? translateOperationalFunction(prop) : prop)
      .join(' ');

  /// Clone with json
  Personnel mergeWith(Map<String, dynamic> json);

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
  });
}

enum PersonnelStatus { mobilized, onscene, retired }

String translatePersonnelStatus(PersonnelStatus status) {
  switch (status) {
    case PersonnelStatus.mobilized:
      return "Mobilisert";
    case PersonnelStatus.onscene:
      return "Ankommet";
    case PersonnelStatus.retired:
      return "Dimittert";
    default:
      return enumName(status);
  }
}

enum OperationalFunction { Commander, UnitLeader, Personnel }

String translateOperationalFunction(OperationalFunction function) {
  switch (function) {
    case OperationalFunction.Commander:
      return "Aksjonsleder";
    case OperationalFunction.UnitLeader:
      return "Lagleder";
    case OperationalFunction.Personnel:
      return "Mannskap";
    default:
      return enumName(function);
  }
}
