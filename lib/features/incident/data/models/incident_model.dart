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

  /// Clone with json
  Incident mergeWith(Map<String, dynamic> json, {String userId}) {
    var clone = IncidentModel.fromJson(json);
    var now = DateTime.now();
    return IncidentModel(
      uuid: clone.uuid ?? this.uuid,
      name: clone.name ?? this.name,
      type: clone.type ?? this.type,
      status: clone.status ?? this.status,
      changed: userId != null
          ? Author(userId: userId, timestamp: now)
          : clone.changed ?? Author.fromJson(this.changed?.toJson()),
      created: clone.created ?? Author.fromJson(this.created?.toJson()),
      occurred: clone.occurred ?? this.occurred,
      justification: clone.justification ?? this.justification,
      exercise: clone.exercise ?? this.exercise,
      reference: clone.reference ?? this.reference,
      passcodes: clone.passcodes ?? Passcodes.fromJson(this.passcodes?.toJson()),
      ipp: clone.ipp ?? Location.fromJson(this.ipp.toJson()),
      meetup: clone.meetup ?? Location.fromJson(this.meetup.toJson()),
      talkgroups: clone.talkgroups ?? this.talkgroups.map((tg) => TalkGroup.fromJson(tg?.toJson())).toList(),
    );
  }

  /// Clone with author
  Incident withAuthor(String userId) {
    var now = DateTime.now();
    return IncidentModel(
      uuid: this.uuid,
      name: this.name,
      type: this.type,
      status: this.status,
      changed: Author(userId: userId, timestamp: now),
      created: this.created ?? Author(userId: userId, timestamp: now),
      occurred: this.occurred,
      justification: this.justification,
      reference: this.reference,
      passcodes: this.passcodes,
      exercise: this.exercise,
      ipp: this.ipp,
      meetup: this.meetup,
      talkgroups: this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }

  /// Clone with author
  Incident copyWith({
    String name,
    IncidentType type,
    IncidentStatus status,
    Author created,
    Author changed,
    DateTime occurred,
    String justification,
    String reference,
    Passcodes passcodes,
    Location ipp,
    Location meetup,
    bool exercise,
    List<TalkGroup> talkGroups,
  }) {
    return IncidentModel(
      uuid: this.uuid,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      created: created ?? this.created,
      changed: changed ?? this.changed,
      occurred: occurred ?? this.occurred,
      justification: justification ?? this.justification,
      reference: reference ?? this.reference,
      exercise: exercise ?? this.exercise,
      passcodes: passcodes ?? Passcodes.fromJson(this.passcodes.toJson()),
      ipp: ipp ?? Location.fromJson(this.ipp.toJson()),
      meetup: meetup ?? Location.fromJson(this.meetup.toJson()),
      talkgroups: talkGroups ?? this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }
}
