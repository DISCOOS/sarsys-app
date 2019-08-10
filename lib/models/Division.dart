import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Division.g.dart';

@JsonSerializable()
class Division extends Equatable {
  final String name;
  final Map<String, String> departments;

  Division({
    @required this.name,
    @required this.departments,
  }) : super([name, departments]);

  /// Factory constructor for creating a new `Division` instance
  factory Division.fromJson(Map<String, dynamic> json) => _$DivisionFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DivisionToJson(this);
}
