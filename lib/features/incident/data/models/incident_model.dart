import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/models/core.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'incident_model.g.dart';

@JsonSerializable()
class IncidentModel extends Incident implements JsonObject<Map<String, dynamic>> {
  IncidentModel({
    @required String uuid,
    @required String name,
    @required IncidentType type,
    @required IncidentStatus status,
    @required DateTime occurred,
    @required List<TalkGroup> talkgroups,
    @required String justification,
    @required Location ipp,
    @required Location meetup,
    @required Passcodes passcodes,
    @required Author created,
    @required Author changed,
    bool exercise = false,
    String reference,
  }) : super(
          uuid: uuid,
          name: name,
          type: type,
          status: status,
          occurred: occurred,
          talkgroups: talkgroups,
          justification: justification,
          ipp: ipp,
          meetup: meetup,
          passcodes: passcodes,
          created: created,
          changed: changed,
          exercise: exercise,
          reference: reference,
        );

  /// Factory constructor for creating a new `IncidentModel` instance
  factory IncidentModel.fromJson(Map<String, dynamic> json) => _$IncidentModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$IncidentModelToJson(this);
}
