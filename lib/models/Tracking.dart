import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Tracking.g.dart';

@JsonSerializable()
class Tracking extends Equatable {
  final String id;
  final TrackingStatus status;
  final Point location;
  final double distance;
  final List<String> devices;
  final List<Point> history;
  final Map<String, List<Point>> tracks;

  Tracking({
    @required this.id,
    @required this.status,
    this.location,
    this.distance,
    this.devices,
    this.history,
    this.tracks = const {},
  }) : super([id, status, location, distance, devices, history, tracks]);

  /// Get searchable string
  get searchable => props.map((prop) => prop is TrackingStatus ? translateTrackingStatus(prop) : prop).join(' ');

  /// Factory constructor for creating a new `Tracking` instance
  factory Tracking.fromJson(Map<String, dynamic> json) => _$TrackingFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingToJson(this);

  /// Clone with given devices and state
  Tracking cloneWith({
    List<String> devices,
    TrackingStatus status,
    Point location,
    double distance,
    List<Point> history,
    Map<String, List<Point>> tracks,
  }) {
    return Tracking(
      id: this.id,
      status: status ?? this.status,
      devices: devices ?? this.devices,
      location: location ?? this.location,
      distance: distance ?? this.distance,
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
