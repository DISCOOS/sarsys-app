

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/core/domain/models/core.dart';

part 'incident_model.g.dart';

@JsonSerializable()
class IncidentModel extends Incident implements JsonObject<Map<String, dynamic>> {
  IncidentModel({
    required String? uuid,
    required String? name,
    required String? summary,
    required IncidentType? type,
    required DateTime? occurred,
    required IncidentStatus? status,
    required List<String>? operations,
    required IncidentResolution? resolution,
    bool? exercise = false,
  }) : super(
          uuid: uuid,
          name: name,
          type: type,
          status: status,
          summary: summary,
          occurred: occurred,
          exercise: exercise,
          operations: operations,
          resolution: resolution,
        );

  /// Factory constructor for creating a new `IncidentModel` instance
  factory IncidentModel.fromJson(Map<String, dynamic> json) => _$IncidentModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$IncidentModelToJson(this);

  /// Clone with json
  Incident mergeWith(Map<String, dynamic> json) {
    var clone = IncidentModel.fromJson(json);
    return IncidentModel(
      uuid: clone.uuid ?? this.uuid,
      name: clone.name ?? this.name,
      type: clone.type ?? this.type,
      status: clone.status ?? this.status,
      summary: clone.summary ?? this.summary,
      occurred: clone.occurred ?? this.occurred,
      exercise: clone.exercise ?? this.exercise,
      operations: clone.operations ?? this.operations,
      resolution: clone.resolution ?? this.resolution,
    );
  }

  /// Clone with author
  Incident copyWith({
    String? name,
    bool? exercise,
    String? summary,
    IncidentType? type,
    DateTime? occurred,
    Passcodes? passcodes,
    IncidentStatus? status,
    List<String>? operations,
    IncidentResolution? resolution,
  }) {
    return IncidentModel(
      uuid: this.uuid,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      occurred: occurred ?? this.occurred,
      exercise: exercise ?? this.exercise,
      operations: operations ?? this.operations,
      resolution: resolution ?? this.resolution,
    );
  }
}
