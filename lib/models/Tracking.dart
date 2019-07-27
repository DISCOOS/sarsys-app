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
  final List<Point> track;

  Tracking({
    @required this.id,
    @required this.status,
    this.location,
    this.distance,
    this.devices,
    this.track,
  }) : super([id, status, location, distance, devices, track]);

  /// Factory constructor for creating a new `Tracking` instance
  factory Tracking.fromJson(Map<String, dynamic> json) => _$TrackingFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingToJson(this);

  /// Clone with given devices and state
  Tracking cloneWith({List<String> devices, TrackingStatus status}) {
    return Tracking(
      id: this.id,
      track: this.track,
      location: this.location,
      distance: this.distance,
      status: status ?? this.status,
      devices: devices ?? this.devices,
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
