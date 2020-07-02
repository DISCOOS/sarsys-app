import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'division_model.g.dart';

@JsonSerializable()
class DivisionModel extends Division {
  DivisionModel({
    @required String uuid,
    @required String name,
    @required String suffix,
    @required AggregateRef<Organisation> organisation,
    @required List<String> departments,
    @required bool active,
  }) : super(
          uuid: uuid,
          name: name,
          suffix: suffix,
          organisation: organisation,
          departments: departments,
          active: active,
        );

  /// Factory constructor for creating a new `DivisionModel` instance
  factory DivisionModel.fromJson(Map<String, dynamic> json) => _$DivisionModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DivisionModelToJson(this);
}
