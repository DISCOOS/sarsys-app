import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Unit.g.dart';

@JsonSerializable()
class Unit extends Equatable {
  final String id;
  final String name;

  Unit({
    @required this.id,
    @required this.name,
  }) : super([id, name]);

  /// Factory constructor for creating a new `Unit` instance
  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitToJson(this);
}
