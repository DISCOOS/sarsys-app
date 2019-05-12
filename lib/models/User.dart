import 'package:equatable/equatable.dart';
import 'package:jose/jose.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'User.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String firstName;
  final String lastName;
  final String userId;

  User({
    @required this.userId,
    this.firstName,
    this.lastName,
  }) : super([
          userId,
          firstName,
          lastName,
        ]);

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Create user from token
  factory User.fromToken(String token) {
    var jwt = new JsonWebToken.unverified(token);
    return User(userId: jwt.claims.subject);
  }
}
