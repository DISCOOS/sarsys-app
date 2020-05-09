import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Incident.g.dart';

@JsonSerializable(
  explicitToJson: true,
  anyMap: true,
)
class Incident extends Aggregate<Map<String, dynamic>> {
  Incident({
    @required String uuid,
    @required this.name,
    @required this.type,
    @required this.status,
    @required this.occurred,
    @required this.talkgroups,
    @required this.justification,
    @required this.ipp,
    @required this.meetup,
    @required this.passcodes,
    @required this.created,
    @required this.changed,
    this.reference,
  }) : super(uuid, fields: [
          name,
          type,
          status,
          occurred,
          talkgroups,
          justification,
          ipp,
          meetup,
          passcodes,
          created,
          changed,
        ]);

  final String name;
  final IncidentType type;
  final IncidentStatus status;
  final DateTime occurred;
  final String justification;
  final List<TalkGroup> talkgroups;
  final Location ipp;
  final Location meetup;
  final Passcodes passcodes;
  final String reference;
  final Author created;
  final Author changed;

  /// Get searchable string
  get searchable => [
        ...props
            .map((prop) => prop is IncidentType
                ? translateIncidentType(prop)
                : (prop is IncidentStatus
                    ? translateIncidentStatus(prop)
                    : (prop) is List<TalkGroup> ? prop.map((tg) => tg.searchable) : prop))
            .toList(),
        "ipp: $ipp",
        "oppmøte: $meetup"
      ].join(' ');

  /// Factory constructor for creating a new `Incident`  instance
  factory Incident.fromJson(Map<String, dynamic> json) => _$IncidentFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$IncidentToJson(this);

  /// Clone with json
  Incident withJson(Map<String, dynamic> json, {String userId}) {
    var clone = Incident.fromJson(json);
    var now = DateTime.now();
    return Incident(
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
    return Incident(
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
      ipp: this.ipp,
      meetup: this.meetup,
      talkgroups: this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }

  /// Clone with author
  Incident cloneWith({
    String name,
    IncidentType type,
    IncidentStatus status,
    Author created,
    Author changed,
    DateTime occured,
    String justification,
    String reference,
    Passcodes passcodes,
    Location ipp,
    Location meetup,
    List<TalkGroup> talkGroups,
  }) {
    return Incident(
      uuid: this.uuid,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      created: created ?? this.created,
      changed: changed ?? this.changed,
      occurred: occured ?? this.occurred,
      justification: justification ?? this.justification,
      reference: reference ?? this.reference,
      passcodes: passcodes ?? Passcodes.fromJson(this.passcodes.toJson()),
      ipp: ipp ?? Location.fromJson(this.ipp.toJson()),
      meetup: meetup ?? Location.fromJson(this.meetup.toJson()),
      talkgroups: talkGroups ?? this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }
}

enum IncidentType { Lost, Distress, Other }

enum IncidentStatus { Registered, Handling, Cancelled, Resolved, Other }

String translateIncidentType(IncidentType type) {
  switch (type) {
    case IncidentType.Lost:
      return "Savnet";
    case IncidentType.Distress:
      return "Nødstedt";
    case IncidentType.Other:
    default:
      return "Annet";
  }
}

String translateIncidentStatus(IncidentStatus status) {
  switch (status) {
    case IncidentStatus.Registered:
      return "Registrert";
    case IncidentStatus.Handling:
      return "Håndteres";
    case IncidentStatus.Cancelled:
      return "Kansellert";
    case IncidentStatus.Resolved:
      return "Løst";
    case IncidentStatus.Other:
    default:
      return "Annet";
  }
}
