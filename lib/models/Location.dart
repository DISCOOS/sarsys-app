import 'package:SarSys/models/Point.dart';
import 'package:equatable/equatable.dart';
import 'package:SarSys/models/Address.dart';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Location.g.dart';

@JsonSerializable()
class Location extends Equatable {
  final Point point;
  final Address address;
  final String description;

  Location({
    @required this.point,
    this.description,
    this.address,
  });

  /// Factory constructor for creating a new `Location` instance
  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$LocationToJson(this);
}
