import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Affiliation.g.dart';

@JsonSerializable()
class Affiliation extends Equatable {
  final String organization;
  final String division;
  final String department;

  Affiliation({
    this.organization,
    this.division,
    this.department,
  }) : super([
          organization,
          division,
          division,
        ]);

  /// Factory constructor for creating a new `Affiliation` instance
  factory Affiliation.fromJson(Map<String, dynamic> json) => _$AffiliationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AffiliationToJson(this);
}
