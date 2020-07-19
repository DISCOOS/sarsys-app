import 'package:flutter/material.dart';

import 'package:SarSys/models/core.dart';

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

  String fname;
  String lname;
  String phone;
  String email;
  String userId;
  bool temporary;

  String get name => "${fname ?? ''} ${lname ?? ''}";
  String get formal => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}. ${lname ?? ''}";
  String get initials => "${fname?.substring(0, 1)?.toUpperCase() ?? ''}${lname?.substring(0, 1)?.toUpperCase() ?? ''}";

  /// Get searchable string
  String get searchable => [...props, formal, initials].join(' ');

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
