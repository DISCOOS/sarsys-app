import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Address.g.dart';

@JsonSerializable()
class Address extends Equatable {
  final List<String> lines;
  final String postalCode;
  final String countryCode;

  Address({
    this.lines,
    this.postalCode,
    this.countryCode,
  }) : super([
          lines,
          postalCode,
          countryCode,
        ]);

  /// Factory constructor for creating a new `Address` instance
  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}
