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
          reference,
        ]);

  /// Factory constructor for creating a new `Incident?  instance
  factory Incident.fromJson(Map<String, dynamic> json) => _$IncidentFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$IncidentToJson(this);
}

enum IncidentType { Lost, Distress, Other }

enum IncidentStatus { Registered, Handling, Other }
