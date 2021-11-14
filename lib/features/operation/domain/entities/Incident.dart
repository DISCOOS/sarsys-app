

import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:meta/meta.dart';

abstract class Incident extends Aggregate<Map<String, dynamic>> {
  Incident({
    required String? uuid,
    required this.name,
    required this.type,
    required this.status,
    required this.summary,
    required this.occurred,
    required this.resolution,
    required this.operations,
    this.exercise = false,
  }) : super(uuid!, fields: [
          name,
          type,
          status,
          summary,
          occurred,
          exercise,
          resolution,
        ]);

  final String? name;
  final bool? exercise;
  final String? summary;
  final IncidentType? type;
  final DateTime? occurred;
  final IncidentStatus? status;
  final List<String>? operations;
  final IncidentResolution? resolution;

  /// Get searchable string
  get searchable => [
        ...props
            .map((prop) => prop is IncidentType
                ? translateIncidentType(prop)
                : (prop is IncidentStatus
                    ? translateIncidentStatus(prop)
                    : (prop is IncidentResolution
                        ? translateIncidentResolution(prop)
                        : prop is List<TalkGroup> ? prop.map((tg) => tg.searchable) : prop)))
            .toList(),
      ].join(' ');

  /// Clone with json
  Incident mergeWith(Map<String, dynamic> json);

  /// Clone with author
  Incident copyWith({
    String? name,
    bool? exercise,
    IncidentType? type,
    DateTime? occurred,
    IncidentStatus? status,
    List<String>? operations,
    IncidentResolution? resolution,
  });
}

enum IncidentType { lost, distress, disaster, other }

String translateIncidentType(IncidentType? type) {
  switch (type) {
    case IncidentType.lost:
      return "Savnet";
    case IncidentType.distress:
      return "Nødstedt";
    case IncidentType.disaster:
      return "Katastrofe";
    case IncidentType.other:
      return "Annet";
  }
  throw ArgumentError('IncidentType ${enumName(type)} not recognized');
}

enum IncidentStatus { registered, handling, closed }

String translateIncidentStatus(IncidentStatus status) {
  switch (status) {
    case IncidentStatus.registered:
      return "Registrert";
    case IncidentStatus.handling:
      return "Håndteres";
    case IncidentStatus.closed:
      return "Lukket";
  }
  throw ArgumentError('Status ${enumName(status)} not recognized');
}

enum IncidentResolution { unresolved, cancelled, duplicate, resolved }

String translateIncidentResolution(IncidentResolution resolution) {
  switch (resolution) {
    case IncidentResolution.unresolved:
      return "Ikke løst";
    case IncidentResolution.duplicate:
      return "Duplikat";
    case IncidentResolution.cancelled:
      return "Kansellert";
    case IncidentResolution.resolved:
      return "Løst";
  }
  throw ArgumentError('Status ${enumName(resolution)} not recognized');
}
