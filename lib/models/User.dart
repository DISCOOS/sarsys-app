import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'User.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String firstName;
  final String lastName;
  final String userId;
  final List<UserRole> roles;

  User({
    @required this.userId,
    this.firstName,
    this.lastName,
    this.roles,
  }) : super([
          userId,
          firstName,
          lastName,
          roles,
        ]);

  bool get isCommander => roles.contains(UserRole.Commander);
  bool get isUnitLeader => roles.contains(UserRole.UnitLeader);
  bool get isPersonnel => roles.contains(UserRole.Personnel);

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Create user from token
  factory User.fromToken(String token) {
    final jwt = JwtClaim.fromMap(_fromJWT(token));
    return User(
        userId: jwt.subject,
        roles: (jwt['roles'] as List)
            ?.map(
              (e) => _$enumDecodeNullable(_$UserRoleEnumMap, e),
            )
            ?.toList());
  }

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

enum UserRole { Commander, UnitLeader, Personnel }
