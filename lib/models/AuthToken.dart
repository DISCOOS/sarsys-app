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
    this.refreshToken,
    this.accessTokenExpiration,
  }) : super([
          idToken,
          accessToken,
          refreshToken,
          accessTokenExpiration,
        ]);

  final String idToken;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiration;

  /// Factory constructor for creating a new `AuthToken` instance
  factory AuthToken.fromJson(Map<String, dynamic> json) => _$AuthTokenFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AuthTokenToJson(this);

  /// Get Token as User
  User asUser() => User.fromToken(accessToken);
}
