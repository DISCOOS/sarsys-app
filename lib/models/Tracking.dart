import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Tracking.g.dart';

@JsonSerializable()
class Tracking extends Equatable {
  final String id;
  final TrackingState state;
  final Point location;
  final double distance;
  final List<Device> devices;
  final List<Point> track;

  Tracking({
    @required this.id,
    @required this.state,
    this.location,
    this.distance,
    this.devices,
    this.track,
  }) : super([id, state, location, distance, devices, track]);

  /// Factory constructor for creating a new `Tracking` instance
  factory Tracking.fromJson(Map<String, dynamic> json) => _$TrackingFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingToJson(this);
}

enum TrackingState { Created, Tracking, Paused, Ended }

String translateTrackingState(TrackingState state) {
  switch (state) {
    case TrackingState.Created:
      return "Opprettet";
    case TrackingState.Paused:
      return "Pauset";
    case TrackingState.Ended:
      return "Avsluttet";
    default:
      return enumName(state);
  }
}
