import 'dart:math';

import 'package:SarSys/models/Point.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Track.g.dart';

@JsonSerializable()
class Track extends Equatable {
  final TrackType type;
  final List<Point> points;

  Track({
    @required this.points,
    @required this.type,
  }) : super([
          type,
          points,
        ]);

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  /// Factory constructor for creating a new `Track`  instance
  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  /// Truncate to number of points and return new [Track] instance
  Track truncate(int count) => Track(
        points: this.points.skip(max(0, points.length - count)).toList(),
        type: this.type,
      );
}

enum TrackType { Device, Aggregate }

String translateTrackType(TrackType type) {
  switch (type) {
    case TrackType.Device:
      return "Apparat";
    case TrackType.Aggregate:
    default:
      return "Aggregert";
  }
}
