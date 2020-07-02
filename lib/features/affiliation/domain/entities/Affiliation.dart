import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/core.dart';

import 'Department.dart';
import 'Division.dart';
import 'Organisation.dart';

part 'Affiliation.g.dart';

@JsonSerializable()
class Affiliation extends ValueObject<Map<String, dynamic>> {
  Affiliation({
    this.org,
    this.div,
    this.dep,
  }) : super([org, div, dep]);

  final AggregateRef<Organisation> org;
  final AggregateRef<Division> div;
  final AggregateRef<Department> dep;

  /// Factory constructor for creating a new `Affiliation` instance
  factory Affiliation.fromJson(Map<String, dynamic> json) => _$AffiliationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AffiliationToJson(this);
}
