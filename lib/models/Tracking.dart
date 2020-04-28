import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'core.dart';

part 'Tracking.g.dart';

@JsonSerializable(
  explicitToJson: true,
)
class Tracking extends Aggregate {
  Tracking({
    /// Tracking id
    @required this.id,

    /// Tracking status
    @required this.status,

    /// Last known position
    this.point,

    /// Total distance in meter
    this.distance,

    /// Average speed in m/s
    this.speed,

    /// Total effort in milliseconds
    this.effort,

    /// List tracked devices
    this.devices = const [],

    /// List of historical points aggregated from temporally and spatially related points in tracks
    this.history = const [],

    /// Map from device id to list of points
    this.tracks = const {},

    /// List of ids of tracking objects being aggregated by this tracking object
    this.aggregates = const [],
  }) : super(id);

  final String id;
  final TrackingStatus status;
  final Point point;
  final double distance;
  final double speed;
  final Duration effort;
  final List<String> devices;
  final List<Point> history;
  final List<String> aggregates;
  final Map<String, Track> tracks;

  /// Get searchable string
  get searchable => props.map((prop) => prop is TrackingStatus ? translateTrackingStatus(prop) : prop).join(' ');

  /// Factory constructor for creating a new `Tracking` instance
  factory Tracking.fromJson(Map<String, dynamic> json) => _$TrackingFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingToJson(this);

  /// Clone with given devices and state
  Tracking cloneWith({
    TrackingStatus status,
    Point point,
    double distance,
    double speed,
    Duration effort,
    List<String> devices,
    List<String> aggregates,
    List<Point> history,
    Map<String, Track> tracks,
  }) {
    return Tracking(
      id: this.id,
      status: status ?? this.status,
      point: point ?? this.point,
      distance: distance ?? this.distance,
      speed: speed ?? this.speed,
      effort: effort ?? this.effort,
      devices: devices ?? this.devices,
      aggregates: aggregates ?? this.aggregates,
      history: history ?? this.history,
      tracks: tracks ?? this.tracks,
    );
  }
}

enum TrackingStatus { None, Created, Tracking, Paused, Closed }

String translateTrackingStatus(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.None:
      return "Ingen";
    case TrackingStatus.Created:
      return "Opprettet";
    case TrackingStatus.Tracking:
      return "Sporer";
    case TrackingStatus.Paused:
      return "Pauset";
    case TrackingStatus.Closed:
      return "Avsluttet";
    default:
      return enumName(status);
  }
}
