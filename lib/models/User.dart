import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/utils/data_utils.dart';

import 'Security.dart';

part 'User.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String userId;
  final String fname;
  final String lname;
  final String uname;
  final String email;
  final String phone;
  final Security security;

  @JsonKey(
    defaultValue: <UserRole>[],
  )
  final List<UserRole> roles;

  @JsonKey(
    defaultValue: <String>[],
  )
  final List<String> passcodes;

  User({
    @required this.userId,
    this.fname,
    this.lname,
    this.uname,
    this.phone,
    this.email,
    this.security,
    this.roles = const [],
    this.passcodes = const [],
  }) : super([
          userId,
          fname,
          lname,
          uname,
          email,
          phone,
          roles,
          passcodes,
        ]);

  String get fullName => '$fname $lname';
  String get shortName => '${fname.substring(0, 1)} $lname';
  String get initials => '${fname.substring(0, 1)}${lname.substring(0, 1)}'.toUpperCase();

  bool get isCommander => roles.contains(UserRole.commander);
  bool get isUnitLeader => roles.contains(UserRole.unit_leader);
  bool get isPersonnel => roles.contains(UserRole.personnel);

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Create user from token
  factory User.fromToken(
    String token, {
    Security security,
    List<String> passcodes,
  }) {
    final json = _fromJWT(token);
    final jwt = JwtClaim.fromMap(json);
    final claims = [
      if (json.hasPath('roles')) ...json['roles'],
      if (json.hasPath('realm_access/roles')) ...json.elementAt('realm_access/roles'),
    ];
    final roles = List<UserRole>.from(_toRoles(claims));
    return User(
      userId: jwt.subject,
      uname: jwt['preferred_username'],
      fname: jwt['given_name'],
      lname: jwt['family_name'],
      email: jwt['email'],
      phone: jwt['phone'],
      roles: roles,
      security: security,
      passcodes: passcodes,
    );
  }

  static Iterable<UserRole> _toRoles(Iterable roles) => roles
      ?.where(
        _$UserRoleEnumMap.containsValue,
      )
      ?.map(
        (e) => _$enumDecodeNullable(_$UserRoleEnumMap, e),
      )
      ?.toSet();

  static Map<String, dynamic> _fromJWT(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('invalid token');
    }
    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('invalid payload');
    }
    return payloadMap;
  }

  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(
      base64Url.decode(output),
    );
  }

  User cloneWith({
    String userId,
    String fname,
    String lname,
    String uname,
    String email,
    String phone,
    Security security,
    List<UserRole> roles,
    List<String> passcodes,
  }) =>
      User(
        userId: userId ?? this.userId,
        fname: fname ?? this.fname,
        lname: lname ?? this.lname,
        uname: uname ?? this.uname,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        security: security ?? this.security,
        roles: List.from(
          roles ?? this.roles ?? [],
        ),
        passcodes: List.from(
          passcodes ?? this.passcodes ?? [],
        ),
      );
}

enum UserRole { commander, unit_leader, personnel }

String translateUserRole(UserRole role) {
  switch (role) {
    case UserRole.commander:
      return "Aksjonsleder";
    case UserRole.personnel:
      return "Mannskap";
    case UserRole.unit_leader:
    default:
      return "Lagleder";
  }
}
