import 'package:SarSys/models/Coordinates.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/core.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Source.dart';

part 'Position.g.dart';

@JsonSerializable()
class Position extends ValueObject<Map<String, dynamic>> {
  Position({
    @required this.geometry,
    @required this.properties,
  }) : super([
          geometry,
          properties,
          PositionType.feature,
        ]);

  final Point geometry;
  final PositionType type = PositionType.feature;
  final PositionProperties properties;

  @JsonKey(ignore: true)
  double get lat => geometry.lat;

  @JsonKey(ignore: true)
  double get lon => geometry.lon;

  @JsonKey(ignore: true)
  double get alt => geometry.alt;

  @JsonKey(ignore: true)
  double get acc => properties.acc;

  @JsonKey(ignore: true)
  double get speed => properties.speed;

  @JsonKey(ignore: true)
  double get bearing => properties.bearing;

  @JsonKey(ignore: true)
  PositionSource get source => properties.source;

  @JsonKey(ignore: true)
  DateTime get timestamp => properties.timestamp;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => geometry.isEmpty;

  factory Position.fromPoint(
    Point point, {
    @required PositionSource source,
    double acc,
    double speed,
    double bearing,
    DateTime timestamp,
  }) {
    return Position.timestamp(
      lat: point.lat,
      lon: point.lon,
      alt: point.alt,
      acc: acc,
      speed: speed,
      bearing: bearing,
      source: source,
      timestamp: DateTime.now(),
    );
  }

  factory Position.now({
    @required double lat,
    @required double lon,
    @required PositionSource source,
    double alt,
    double acc,
    double speed,
    double bearing,
  }) {
    return Position.timestamp(
      lat: lat,
      lon: lon,
      alt: alt,
      acc: acc,
      speed: speed,
      bearing: bearing,
      source: source,
      timestamp: DateTime.now(),
    );
  }

  factory Position.timestamp({
    @required double lat,
    @required double lon,
    @required DateTime timestamp,
    double acc,
    double alt,
    double speed,
    double bearing,
    PositionSource source,
  }) {
    return Position(
      geometry: Point.fromCoords(
        lat: lat,
        lon: lon,
        alt: alt,
      ),
      properties: PositionProperties(
        acc: acc,
        speed: speed,
        bearing: bearing,
        timestamp: timestamp,
        source: source,
      ),
    );
  }

  /// Factory constructor for creating a new `Position`  instance
  factory Position.fromJson(Map<String, dynamic> json) => _$PositionFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionToJson(this);

  /// Clone with given overrides
  Position cloneWith({
    double lat,
    double lon,
    double alt,
    double acc,
    double speed,
    double bearing,
    PositionSource source,
    DateTime timestamp,
  }) =>
      Position(
        properties: PositionProperties(
          source: source ?? this.source,
          timestamp: timestamp ?? this.timestamp,
          acc: acc ?? this.acc,
          speed: speed ?? this.speed,
          bearing: bearing ?? this.bearing,
        ),
        geometry: Point(
          coordinates: Coordinates(
            lon: lon ?? this.lon,
            lat: lat ?? this.lat,
            alt: alt ?? this.alt,
          ),
        ),
      );
}

enum PositionType { feature }

String translatePositionType(PositionType type) {
  switch (type) {
    case PositionType.feature:
    default:
      return "Posisjon";
  }
}

enum PositionSource { manual, device, aggregate }

String translatePositionSource(PositionSource type) {
  switch (type) {
    case PositionSource.device:
      return "Apparat";
    case PositionSource.aggregate:
      return "Aggregert";
    case PositionSource.manual:
    default:
      return "Manuell";
  }
}

@JsonSerializable()
class PositionProperties extends Equatable {
  PositionProperties({
    @required this.acc,
    @required this.timestamp,
    this.speed,
    this.bearing,
    this.source = PositionSource.manual,
  }) : super();

  @override
  List<Object> get props => [
        acc,
        timestamp,
        source,
      ];

  /// The estimated horizontal accuracy of the position in meters.
  @JsonKey(name: 'accuracy')
  final double acc;

  /// Speed at which the device is traveling in meters per second over ground.
  final double speed;

  /// The heading in which the device is traveling in degrees.
  final double bearing;

  /// The [DateTime] at which this position was determined.
  final DateTime timestamp;

  /// The [PositionSource] type
  final PositionSource source;

  /// Factory constructor for creating a new `Point`  instance
  factory PositionProperties.fromJson(Map<String, dynamic> json) => _$PositionPropertiesFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionPropertiesToJson(this);

  PositionProperties cloneWith({
    double acc,
    SourceType source,
    DateTime timestamp,
  }) =>
      PositionProperties(
        acc: acc ?? this.acc,
        speed: speed ?? this.speed,
        bearing: bearing ?? this.bearing,
        source: source ?? this.source,
        timestamp: timestamp ?? this.timestamp,
      );
}

abstract class Positionable<T> extends Aggregate<T> {
  Positionable(
    String uuid,
    this.position, {
    List fields = const [],
  }) : super(uuid, fields: [position, ...fields]);
  final Position position;
}
