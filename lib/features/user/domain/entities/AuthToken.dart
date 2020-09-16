import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'User.dart';

part 'AuthToken.g.dart';

@JsonSerializable()
class AuthToken extends Equatable {
  AuthToken({
    @required this.accessToken,
    this.idToken,
    this.clientId,
    this.refreshToken,
    this.accessTokenExpiration,
  }) : super([
          idToken,
          clientId,
          accessToken,
          refreshToken,
          accessTokenExpiration,
        ]);

  final String idToken;
  final String clientId;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiration;

  /// Check if token is valid
  @protected
  bool get isValid => !isExpired;

  /// Check if token is expired
  @protected
  bool get isExpired => accessTokenExpiration.isBefore(DateTime.now());

  /// Factory constructor for creating a new `AuthToken` instance
  factory AuthToken.fromJson(Map<String, dynamic> json) => _$AuthTokenFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AuthTokenToJson(this);

  /// Get current user id
  String get userId => toUser().userId;

  /// Get Token as User
  User toUser({
    Security security,
    List<String> passcodes,
  }) =>
      User.fromTokens(
        accessToken,
        idToken: idToken,
        security: security,
        passcodes: passcodes,
      );
}
