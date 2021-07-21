// @dart=2.11

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/core/domain/models/core.dart';

abstract class Person extends Aggregate<Map<String, dynamic>> {
  Person({
    @required String uuid,
    @required this.fname,
    @required this.lname,
    @required this.phone,
    @required this.email,
    @required this.userId,
    @required this.temporary,
  }) : super(uuid, fields: [
          fname,
          lname,
          phone,
          email,
          userId,
          temporary,
        ]);

  final String fname;
  final String lname;
  final String phone;
  final String email;
  final String userId;
  final bool temporary;

  String get name => "${fname ?? ''} ${lname ?? ''}".trim();
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

  /// Get searchable string
  String get searchable => [...props, formal, initials].join(' ');

  /// Get [Person] reference
  AggregateRef<Person> toRef();

  Person copyWith({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool temporary,
  });
}
