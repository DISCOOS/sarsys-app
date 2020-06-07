import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/models/core.dart';
import 'package:meta/meta.dart';

abstract class Incident extends Aggregate<Map<String, dynamic>> {
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
    this.exercise = false,
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
          exercise,
          reference,
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
  final bool exercise;

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

  /// Clone with json
  Incident mergeWith(Map<String, dynamic> json, {String userId});

  /// Clone with author
  Incident withAuthor(String userId);

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
  });
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
