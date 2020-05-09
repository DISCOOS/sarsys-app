import 'package:SarSys/utils/data_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'AggregateRef.dart';
import 'Source.dart';
import 'converters.dart';
import 'core.dart';
import 'Position.dart';
import 'Track.dart';

part 'Tracking.g.dart';

@JsonSerializable()
class Tracking extends Positionable<Map<String, dynamic>> {
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
    this.sources = const [],

    /// List of historical positions aggregated from temporally and spatially related positions in tracks
    this.history = const [],

    /// Map from track id to list of positions
    this.tracks = const [],
  }) : super(uuid, position, fields: [
          status,
          position,
          distance,
          speed,
          effort,
          sources,
          history,
          tracks,
        ]);

  final TrackingStatus status;
  final double speed;
  final Duration effort;
  final double distance;
  final List<Source> sources;
  final List<Position> history;
  final List<Track> tracks;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => sources.isEmpty;

  /// Get searchable string
  get searchable => props.map((prop) => prop is TrackingStatus ? translateTrackingStatus(prop) : prop).join(' ');

  /// Factory constructor for creating a new `Tracking` instance
  factory Tracking.fromJson(Map<String, dynamic> json) => _$TrackingFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingToJson(this);

  /// Clone with given devices and state
  Tracking cloneWith({
    double speed,
    double distance,
    Duration effort,
    Position position,
    List<Source> sources,
    List<Position> history,
    TrackingStatus status,
    List<Track> tracks,
  }) {
    return Tracking(
      uuid: this.uuid,
      status: status ?? this.status,
      position: position ?? this.position,
      distance: distance ?? this.distance,
      speed: speed ?? this.speed,
      effort: effort ?? this.effort,
      sources: sources ?? this.sources,
      history: history ?? this.history,
      tracks: tracks ?? this.tracks,
    );
  }

  /// Clone with json
  Tracking withJson(Map<String, dynamic> json) {
    var clone = Tracking.fromJson(json);
    return cloneWith(
      status: clone.status ?? status,
      position: clone.position ?? position,
      distance: clone.distance ?? distance,
      speed: clone.speed ?? speed,
      effort: clone.effort ?? effort,
      history: clone.history ?? history,
      tracks: clone.tracks ?? tracks,
    );
  }

  Tracking asTracking() => cloneWith(
        status: TrackingStatus.tracking,
      );

  Tracking asClosed() => cloneWith(
        status: TrackingStatus.closed,
      );
}

enum TrackingStatus {
  none,
  created,
  tracking,
  paused,
  closed,
}

String translateTrackingStatus(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.none:
      return "Ingen";
    case TrackingStatus.created:
      return "Opprettet";
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
  @JsonKey(
    fromJson: toTrackingRef,
    nullable: true,
    includeIfNull: false,
  )
  final AggregateRef<Tracking> tracking;
}
