import 'package:SarSys/models/core.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'conflict_model.g.dart';

enum ConflictType {
  merge,
  exists,
  deleted,
}

@JsonSerializable()
class ConflictModel extends JsonObject<Map<String, dynamic>> {
  ConflictModel({
    @required this.type,
    this.error,
    this.mine,
    this.yours,
  }) : super([type, error, mine, yours]);

  final ConflictType type;
  final String error;
  final List<Map<String, dynamic>> mine;
  final List<Map<String, dynamic>> yours;

  /// Factory constructor for creating a new `ConflictModel` instance
  factory ConflictModel.fromJson(Map<String, dynamic> json) => _$ConflictModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$ConflictModelToJson(this);
}
