import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/utils/data_utils.dart';

part 'User.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String userId;
  final String fname;
  final String lname;
  final String uname;
  final String email;
  final String phone;
  final List<UserRole> roles;

  User({
    @required this.userId,
    this.fname,
    this.lname,
    this.uname,
    this.roles,
    this.phone,
    this.email,
  }) : super([
          userId,
          fname,
          lname,
          roles,
        ]);

  String get name => '$fname $lname';
  bool get isCommander => roles.contains(UserRole.commander);
  bool get isUnitLeader => roles.contains(UserRole.unit_leader);
  bool get isPersonnel => roles.contains(UserRole.personnel);

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Create user from token
  factory User.fromToken(String token) {
    final json = _fromJWT(token);
    final jwt = JwtClaim.fromMap(json);
    final claims = [
      ...json['roles'],
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
    return utf8.decode(base64Url.decode(output));
  }
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
