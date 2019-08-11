import 'package:SarSys/models/Division.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Organization.g.dart';

@JsonSerializable()
class Organization extends Equatable {
  final String name;
  final String alias;
  final String pattern;
  final Map<String, String> functions;
  final Map<String, Division> divisions;

  @JsonKey(name: "talk_groups")
  final Map<String, List<String>> talkGroups;

  Organization({
    @required this.name,
    @required this.alias,
    @required this.pattern,
    @required this.functions,
    @required this.divisions,
    @required this.talkGroups,
  }) : super([name, alias, pattern, functions, divisions, talkGroups]);

  /// Factory constructor for creating a new `Organization` instance
  factory Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OrganizationToJson(this);
}
