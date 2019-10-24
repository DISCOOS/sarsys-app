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
  final PointType type;

  Point({
    @required this.lat,
    @required this.lon,
    @required this.timestamp,
    this.alt,
    this.acc,
    PointType type,
  })  : this.type = type ?? PointType.Manual,
        super([
          lat,
          lon,
          alt,
          acc,
          timestamp,
          type,
        ]);

  bool get isEmpty => lat == 0 && lon == 0;
  bool get isNotEmpty => !isEmpty;

  /// Factory constructor for empty `Point`
  factory Point.now(
    double lat,
    double lon, {
    double acc,
    double alt,
    PointType type,
  }) {
    return Point(
      lat: lat,
      lon: lon,
      acc: acc,
      alt: alt,
      type: type,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for creating a new `Point`  instance
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PointToJson(this);
}

enum PointType { Manual, Personnel, Device, Aggregated }

String translatePointType(PointType type) {
  switch (type) {
    case PointType.Manual:
      return "Manuell";
    case PointType.Device:
      return "Apparat";
    case PointType.Device:
      return "Mannskap";
    case PointType.Aggregated:
    default:
      return "Aggregert";
  }
}
