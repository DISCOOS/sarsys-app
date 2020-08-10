import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Source.dart';
import 'Track.dart';

abstract class Tracking extends Positionable<Map<String, dynamic>> {
  Tracking({
    /// Tracking id
    @required String uuid,

    /// Tracking status
    @required this.status,

    /// Last known position
    Position position,

    /// Total distance in meter
    this.distance,

    /// Average speed in m/s
    this.speed,

    /// Total effort in milliseconds
    this.effort,

    /// List of tracked sources
    List<Source> sources = const [],

    /// List of historical positions aggregated from temporally and spatially related positions in tracks
    List<Position> history = const [],

    /// Map from track id to list of positions
    List<Track> tracks = const [],
  })  : tracks = tracks ?? [],
        sources = sources ?? [],
        history = history ?? [],
        super(uuid, position, fields: [
          status,
          position,
          distance,
          speed,
          effort,
          sources,
          history,
          tracks,
        ]);

  final double speed;
  final Duration effort;
  final double distance;
  final List<Track> tracks;
  final List<Source> sources;
  final TrackingStatus status;
  final List<Position> history;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => sources.isEmpty;

  /// Get searchable string
  get searchable => props.map((prop) => prop is TrackingStatus ? translateTrackingStatus(prop) : prop).join(' ');

  /// Clone with given devices and state
  Tracking copyWith({
    double speed,
    double distance,
    Duration effort,
    Position position,
    List<Source> sources,
    List<Position> history,
    TrackingStatus status,
    List<Track> tracks,
  });

  /// Clone with json
  Tracking withJson(Map<String, dynamic> json);

  Tracking asTracking() => copyWith(
        status: TrackingStatus.tracking,
      );

  Tracking asClosed() => copyWith(
        status: TrackingStatus.closed,
      );
}

enum TrackingStatus {
  none,
  ready,
  tracking,
  paused,
  closed,
}

String translateTrackingStatus(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.none:
      return "Ingen";
    case TrackingStatus.ready:
      return "Klar";
    case TrackingStatus.tracking:
      return "Sporer";
    case TrackingStatus.paused:
      return "Pauset";
    case TrackingStatus.closed:
      return "Avsluttet";
    default:
      return enumName(status);
  }
}

/// Aggregates that are tracked by a |Tracking]
/// instance should extend or implement this class
abstract class Trackable<T> extends Aggregate<T> {
  Trackable(String uuid, this.tracking, {List fields = const []}) : super(uuid, fields: fields);
  @JsonKey(fromJson: toTrackingRef)
  final AggregateRef<Tracking> tracking;
}
