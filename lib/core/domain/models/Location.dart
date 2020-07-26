import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/domain/models/Address.dart';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Location.g.dart';

@JsonSerializable()
class Location extends ValueObject<Map<String, dynamic>> {
  final Point point;
  final Address address;
  final String description;

  Location({
    @required this.point,
    this.description,
    this.address,
  }) : super([
          point,
          address,
          description,
        ]);

  /// Factory constructor for creating a new `Location` instance
  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$LocationToJson(this);

  Location cloneWith({
    Point point,
    Address address,
    String description,
  }) =>
      Location(
        point: point ?? this.point,
        address: address ?? this.address,
        description: description ?? this.description,
      );
}
