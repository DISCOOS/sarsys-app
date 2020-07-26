import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/operation/domain/entities/Author.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';

import 'Passcodes.dart';

abstract class Operation extends Aggregate<Map<String, dynamic>> {
  Operation({
    @required String uuid,
    @required this.name,
    @required this.type,
    @required this.author,
    @required this.status,
    @required this.resolution,
    @required this.talkgroups,
    @required this.justification,
    @required this.ipp,
    @required this.meetup,
    @required this.passcodes,
    @required this.incident,
    this.reference,
    this.commander,
  }) : super(uuid, fields: [
          name,
          type,
          author,
          status,
          resolution,
          talkgroups,
          justification,
          ipp,
          meetup,
          passcodes,
          incident,
          reference,
          commander,
        ]);

  final String name;
  final Location ipp;
  final Author author;
  final Location meetup;
  final String reference;
  final OperationType type;
  final Passcodes passcodes;
  final String justification;
  final OperationStatus status;

  @JsonKey(
    // Workaround for missing readOnly: true
    // Depends on include_if_null: false
    toJson: JsonUtils.toNull,
  )
  final List<TalkGroup> talkgroups;

  final OperationResolution resolution;
  final AggregateRef<Incident> incident;
  final AggregateRef<Personnel> commander;

  /// Get searchable string
  get searchable => [
        ...props
            .map((prop) => prop is OperationType
                ? translateOperationType(prop)
                : (prop is OperationStatus
                    ? translateOperationStatus(prop)
                    : (prop is OperationResolution
                        ? translateOperationResolution(resolution)
                        : prop is List<TalkGroup> ? prop.map((tg) => tg.searchable) : prop)))
            .toList(),
        "ipp: $ipp",
        "oppmøte: $meetup"
      ].join(' ');

  /// Clone with author
  Operation withAuthor(String userId);

  /// Clone with json
  Operation mergeWith(Map<String, dynamic> json);

  /// Clone with author
  Operation copyWith({
    String name,
    Location ipp,
    bool exercise,
    Author author,
    Location meetup,
    String reference,
    DateTime occurred,
    OperationType type,
    Passcodes passcodes,
    String justification,
    OperationStatus status,
    List<TalkGroup> talkGroups,
    OperationResolution resolution,
    AggregateRef<Incident> incident,
    AggregateRef<Personnel> commander,
  });
}

enum OperationType { search, rescue, other }

String translateOperationType(OperationType type) {
  switch (type) {
    case OperationType.search:
      return "Søk";
    case OperationType.rescue:
      return "Redning";
    case OperationType.other:
      return "Annet";
  }
  throw ArgumentError('OperationType ${enumName(type)} not recognized');
}

enum OperationStatus { planned, enroute, onscene, completed }

String translateOperationStatus(OperationStatus status) {
  switch (status) {
    case OperationStatus.planned:
      return "Planlagt";
    case OperationStatus.enroute:
      return "På vei";
    case OperationStatus.onscene:
      return "Utføres";
    case OperationStatus.completed:
      return "Avsluttet";
  }
  throw ArgumentError('Status ${enumName(status)} not recognized');
}

enum OperationResolution { unresolved, cancelled, duplicate, resolved }

String translateOperationResolution(OperationResolution resolution) {
  switch (resolution) {
    case OperationResolution.unresolved:
      return "Ikke løst";
    case OperationResolution.duplicate:
      return "Duplikat";
    case OperationResolution.cancelled:
      return "Kansellert";
    case OperationResolution.resolved:
      return "Løst";
  }
  throw ArgumentError('Status ${enumName(resolution)} not recognized');
}
