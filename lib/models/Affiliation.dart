import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Affiliation.g.dart';

@JsonSerializable()
class Affiliation extends Equatable {
  final String orgId;
  final String divId;
  final String depId;

  Affiliation({
    this.orgId,
    this.divId,
    this.depId,
  }) : super([
          orgId,
          divId,
          depId,
        ]);

  /// Factory constructor for creating a new `Affiliation` instance
  factory Affiliation.fromJson(Map<String, dynamic> json) => _$AffiliationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AffiliationToJson(this);
}
