import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Organization.g.dart';

@JsonSerializable()
class Organization extends Equatable {
  final String id;
  final String name;
  final String alias;
  final String pattern;

  Organization({
    @required this.id,
    @required this.name,
    @required this.alias,
    @required this.pattern,
  }) : super([id, name, pattern]);

  /// Factory constructor for creating a new `Organization` instance
  factory Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OrganizationToJson(this);
}
