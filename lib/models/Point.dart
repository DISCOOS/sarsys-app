import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Coordinates.dart';
import 'converters.dart';
import 'core.dart';

part 'Point.g.dart';

@JsonSerializable()
class Point extends ValueObject<Map<String, dynamic>> {
  Point({
    @required this.coordinates,
  }) : super([
          coordinates,
          PointType.point,
        ]);

  @JsonKey(ignore: true)
  double get lat => coordinates.lat;

  @JsonKey(ignore: true)
  double get lon => coordinates.lon;

  @JsonKey(ignore: true)
  double get alt => coordinates.alt;

  final PointType type = PointType.point;

  @JsonKey(fromJson: coordsFromJson, toJson: coordsToJson)
  final Coordinates coordinates;

  bool get isEmpty => coordinates.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Factory constructor for creating a new `Point`  instance
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  /// Factory constructor for creating a new `Point`  instance
  factory Point.fromCoords({
    @required double lat,
    @required double lon,
    double alt,
  }) =>
      Point(
        coordinates: Coordinates(
          lat: lat,
          lon: lon,
          alt: alt,
        ),
      );

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PointToJson(this);
}

enum PointType { point }
