import 'package:SarSys/core/domain/models/core.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Address.g.dart';

@JsonSerializable()
class Address extends ValueObject<Map<String, dynamic>> {
  final List<String> lines;
  final String postalCode;
  final String countryCode;

  Address({
    @required this.lines,
    @required this.postalCode,
    @required this.countryCode,
  }) : super([
          lines,
          postalCode,
          countryCode,
        ]);

  @override
  List<Object> get props => [
        lines,
        postalCode,
        countryCode,
      ];

  /// Factory constructor for creating a new `Address` instance
  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}
