import 'package:SarSys/features/affiliation/domain/entities/FleetMap.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'organisation_model.g.dart';

@JsonSerializable()
class OrganisationModel extends Organisation {
  OrganisationModel({
    @required String uuid,
    @required String name,
    @required String prefix,
    @required FleetMap fleetMap,
    @required List<String> divisions,
    @required bool active,
  }) : super(
          uuid: uuid,
          name: name,
          prefix: prefix,
          fleetMap: fleetMap,
          divisions: divisions,
          active: active,
        );

  /// Clone with [FleetMap] for this organisation
  OrganisationModel cloneWith(FleetMap fleetMap) => OrganisationModel(
        uuid: uuid,
        name: name,
        fleetMap: fleetMap,
        divisions: divisions,
        prefix: fleetMap.prefix,
        active: active,
      );

  /// Factory constructor for creating a new `organisationModel` instance
  factory OrganisationModel.fromJson(Map<String, dynamic> json) => _$OrganisationModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OrganisationModelToJson(this);

  @override
  AggregateRef<Organisation> toRef() => uuid != null ? AggregateRef.fromType<OrganisationModel>(uuid) : null;
}
