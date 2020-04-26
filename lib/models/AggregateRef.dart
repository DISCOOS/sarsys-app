import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AggregateRef.g.dart';

@JsonSerializable()
class AggregateRef extends Equatable {
  final String type;
  final String uuid;

  AggregateRef({
    @required this.uuid,
    @required this.type,
  }) : super([
          uuid,
          type,
        ]);

  /// Factory constructor for creating a new `AggregateRef` instance
  factory AggregateRef.fromJson(Map<String, dynamic> json) => _$AggregateRefFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AggregateRefToJson(this);
}
