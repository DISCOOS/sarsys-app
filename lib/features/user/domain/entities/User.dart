

import 'dart:convert';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:equatable/equatable.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/core/extensions.dart';

import 'Security.dart';

part 'User.g.dart';

@JsonSerializable()
class User extends Equatable {
  User({
    required this.userId,
    this.fname,
    this.lname,
    this.uname,
    this.phone,
    this.email,
    this.security,
    this.org,
    this.div,
    this.dep,
    this.roles = const [],
    this.passcodes = const [],
  });

  final String? userId;
  final String? fname;
  final String? lname;
  final String? uname;
  final String? email;
  final String? phone;
  final String? org;
  final String? div;
  final String? dep;
  final Security? security;

  @JsonKey(
    defaultValue: <UserRole>[],
  )
  final List<UserRole?> roles;

  @JsonKey(
    defaultValue: <String>[],
  )
  final List<Passcodes>? passcodes;

  bool get isAffiliated => org != null || div != null || dep != null;

  @override
  List<Object?> get props => [
        userId,
        fname,
        lname,
        uname,
        email,
        phone,
        org,
        div,
        dep,
        roles,
        passcodes,
      ];

  String get fullName => '$fname $lname';
  String get shortName => '${fname!.substring(0, 1)} $lname';
  String get initials => '${fname!.substring(0, 1)}${lname!.substring(0, 1)}'.toUpperCase();

  bool get hasRoles => roles.isNotEmpty;

  // TODO: Implement admin role
  bool get isAdmin => false;
  bool get isUntrusted => !isTrusted;
  bool get isTrusted => security?.trusted ?? false;
  bool get isCommander => roles.contains(UserRole.commander);
  bool get isPersonnel => roles.contains(UserRole.personnel);
  bool get isUnitLeader => roles.contains(UserRole.unit_leader);
  bool get isPlanningChief => roles.contains(UserRole.planning_chief);
  bool get isOperationsChief => roles.contains(UserRole.operations_chief);
  bool get isLeader => isCommander || isUnitLeader || isPlanningChief || isOperationsChief;

  bool isAuthor(Operation operation) => operation.author!.userId == userId;

  User authorize(Passcodes? codes) => copyWith(
        passcodes: (passcodes!.contains(codes) ? passcodes : List<Passcodes>.from(passcodes!))!
          ..add(codes!),
      );

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Create user from token
  factory User.fromTokens(
    String accessToken, {
    String? org,
    String? div,
    String? dep,
    String? idToken,
    Security? security,
    List<Passcodes>? passcodes,
  }) {
    final json = _fromJWT(accessToken);
    final jwt = JwtClaim.fromMap(json);
    final claims = [
      if (json.hasPath('roles')) ...json['roles'],
      if (json.hasPath('realm_access_roles')) ...json.elementAt('realm_access_roles'),
    ];
    final roles = List<UserRole>.from(_toRoles(claims));
    var user = User(
      userId: jwt.subject,
      uname: jwt['preferred_username'],
      fname: jwt['given_name'],
      lname: jwt['family_name'],
      email: jwt['email'],
      phone: json['phone'],
      org: json['organisation'] ?? org,
      div: json['division'] ?? div,
      dep: json['department'] ?? dep,
      roles: roles,
      security: security,
      passcodes: passcodes,
    );
    if (idToken != null) {
      final idJson = _fromJWT(idToken);
      final idJwt = JwtClaim.fromMap(idJson);
      final affiliation = Map.from(idJwt['affiliation'] ?? {});
      return user.copyWith(
        phone: idJwt['phone'] ?? idJwt['phone_number'],
        org: affiliation['organisation'],
        div: affiliation['division'],
        dep: affiliation['department'],
      );
    }
    return user;
  }

  static Iterable<UserRole?> _toRoles(Iterable roles) => roles
      .where(
        _$UserRoleEnumMap.containsValue,
      )
      .map(
        (e) => _$enumDecodeNullable(_$UserRoleEnumMap, e),
      )
      .toSet();

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

  User copyWith({
    String? userId,
    String? fname,
    String? lname,
    String? uname,
    String? email,
    String? phone,
    String? org,
    String? div,
    String? dep,
    Security? security,
    List<UserRole>? roles,
    List<Passcodes>? passcodes,
  }) =>
      User(
        userId: userId ?? this.userId,
        fname: fname ?? this.fname,
        lname: lname ?? this.lname,
        uname: uname ?? this.uname,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        org: org ?? this.org,
        div: div ?? this.div,
        dep: dep ?? this.dep,
        security: security ?? this.security,
        roles: List.from(
          roles ?? this.roles,
        ),
        passcodes: List.from(
          passcodes ?? this.passcodes ?? [],
        ),
      );
}

enum UserRole {
  commander,
  planning_chief,
  operations_chief,
  unit_leader,
  personnel,
}

String translateUserRole(UserRole? role) {
  switch (role) {
    case UserRole.commander:
      return "Aksjonsleder";
    case UserRole.planning_chief:
      return "Søksleder";
    case UserRole.operations_chief:
      return "Ressursleder";
    case UserRole.unit_leader:
      return "Lagleder";
    case UserRole.personnel:
    default:
      return "Mannskap";
  }
}

String translateUserRoleAbbr(UserRole? role) {
  switch (role) {
    case UserRole.commander:
      return "AL";
    case UserRole.planning_chief:
      return "SL";
    case UserRole.operations_chief:
      return "RL";
    case UserRole.unit_leader:
      return "LL";
    case UserRole.personnel:
    default:
      return "MS";
  }
}
