import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Incident.g.dart';

@JsonSerializable()
class Incident extends Equatable {
  final String id;
  final String name;
  final IncidentType type;
  final IncidentStatus status;
  final DateTime occurred;
  final String justification;
  final List<TalkGroup> talkgroups;
  final Point ipp;
  final Passcodes passcodes;
  final String reference;
  final Author created;
  final Author changed;

  Incident({
    @required this.id,
    @required this.name,
    @required this.type,
    @required this.status,
    @required this.occurred,
    @required this.talkgroups,
    @required this.justification,
    @required this.ipp,
    @required this.passcodes,
    @required this.created,
    @required this.changed,
    this.reference,
  }) : super([
          id,
          name,
          type,
          status,
          occurred,
          talkgroups,
          justification,
          ipp,
          passcodes,
          created,
          changed,
          reference,
        ]);

  /// Factory constructor for creating a new `Incident`  instance
  factory Incident.fromJson(Map<String, dynamic> json) => _$IncidentFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$IncidentToJson(this);

  /// Clone with author
  Incident withAuthor(String userId) {
    var now = DateTime.now();
    return Incident(
      id: this.id,
      name: this.name,
      type: this.type,
      status: this.status,
      changed: Author(userId: userId, timestamp: now),
      created: this.created ?? Author(userId: userId, timestamp: now),
      occurred: this.occurred,
      justification: this.justification,
      passcodes: this.passcodes,
      ipp: this.ipp,
      talkgroups: this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }
}

enum IncidentType { Lost, Distress, Other }

enum IncidentStatus { Registered, Handling, Other }
