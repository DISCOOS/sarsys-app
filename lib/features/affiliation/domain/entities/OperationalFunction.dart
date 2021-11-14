

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'OperationalFunction.g.dart';

@JsonSerializable()
class OperationalFunction extends Equatable {
  final String? name;
  final String? pattern;

  OperationalFunction({
    required this.name,
    required this.pattern,
  });

  @override
  List<Object?> get props => [
        name,
        pattern,
      ];

  /// Get searchable string
  get searchable => props.join(' ');

  /// Factory constructor for creating a new `OperationalFunction`  instance
  factory OperationalFunction.fromJson(Map<String, dynamic> json) => _$OperationalFunctionFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OperationalFunctionToJson(this);
}
