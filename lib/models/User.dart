import 'package:equatable/equatable.dart';
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
    @required this.firstName,
    @required this.lastName,
  }) : super([
          userId,
          firstName,
          lastName,
        ]);

  /// Factory constructor for creating a new `User` instance
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
