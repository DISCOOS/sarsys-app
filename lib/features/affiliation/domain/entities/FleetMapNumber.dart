

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/core/domain/models/core.dart';

part 'FleetMapNumber.g.dart';

@JsonSerializable()
class FleetMapNumber extends JsonObject {
  FleetMapNumber({
    required this.name,
    required this.suffix,
  }) : super([name, suffix]);

  final String? name;
  final String? suffix;

  /// Factory constructor for creating a new `FleetMapNumber` instance
  factory FleetMapNumber.fromJson(Map<String, dynamic> json) => _$FleetMapNumberFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$FleetMapNumberToJson(this);
}
