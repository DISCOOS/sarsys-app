import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Point.g.dart';

@JsonSerializable()
class Point extends Equatable {
  final double lat;
  final double lon;
  final double alt;
  final double acc;
  final DateTime timestamp;

  Point({
    @required this.lat,
    @required this.lon,
    @required this.timestamp,
    this.alt,
    this.acc,
  }) : super([
          lat,
          lon,
          timestamp,
          alt,
          acc,
        ]);

  bool get isEmpty => lat == 0 && lon == 0;

  /// Factory constructor for empty `Point`
  factory Point.now(double lat, double lon) {
    return Point(
      lat: lat,
      lon: lon,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for creating a new `Point`  instance
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PointToJson(this);
}
