import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/core/domain/models/Coordinates.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/domain/models/core.dart';

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
  final PositionProperties properties;
  final PositionType type = PositionType.feature;

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
  bool get isMoving => properties.isMoving;

  @JsonKey(ignore: true)
  Activity get activity => properties.activity;

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
    bool isMoving,
    double bearing,
    Activity activity,
    DateTime timestamp,
  }) {
    return Position.timestamp(
      lat: point.lat,
      lon: point.lon,
      alt: point.alt,
      acc: acc,
      speed: speed,
      source: source,
      bearing: bearing,
      isMoving: isMoving,
      activity: activity,
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
    bool isMoving,
    double bearing,
    Activity activity,
  }) {
    return Position.timestamp(
      lat: lat,
      lon: lon,
      alt: alt,
      acc: acc,
      speed: speed,
      source: source,
      bearing: bearing,
      isMoving: isMoving,
      activity: activity,
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
    bool isMoving,
    double bearing,
    Activity activity,
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
        source: source,
        bearing: bearing,
        isMoving: isMoving,
        activity: activity,
        timestamp: timestamp,
      ),
    );
  }

  LatLng toLatLng() => LatLng(lat, lon);

  /// Factory constructor for creating a new `Position`  instance
  factory Position.fromJson(Map<String, dynamic> json) => _$PositionFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionToJson(this);

  /// Clone with given overrides
  Position copyWith({
    double lat,
    double lon,
    double alt,
    double acc,
    double speed,
    double bearing,
    Activity activity,
    DateTime timestamp,
    PositionSource source,
  }) =>
      Position(
        geometry: Point(
          coordinates: Coordinates(
            lon: lon ?? this.lon,
            lat: lat ?? this.lat,
            alt: alt ?? this.alt,
          ),
        ),
        properties: PositionProperties(
          acc: acc ?? this.acc,
          speed: speed ?? this.speed,
          source: source ?? this.source,
          bearing: bearing ?? this.bearing,
          activity: activity ?? this.activity,
          isMoving: isMoving ?? this.isMoving,
          timestamp: timestamp ?? this.timestamp,
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
    this.isMoving,
    Activity activity,
    this.source = PositionSource.manual,
  })  : activity = activity ?? Activity.unknown,
        super();

  @override
  List<Object> get props => [
        acc,
        source,
        activity,
        isMoving,
        timestamp,
      ];

  /// The estimated horizontal accuracy of the position in meters.
  @JsonKey(name: 'accuracy')
  final double acc;

  /// Speed at which the device is traveling in meters per second over ground.
  final double speed;

  /// The heading in which the device is traveling in degrees.
  final double bearing;

  /// [True] if devices was moving when positions was sampled
  final bool isMoving;

  /// Estimated activity type with confidence
  final Activity activity;

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
    bool isMoving,
    SourceType source,
    DateTime timestamp,
  }) =>
      PositionProperties(
        acc: acc ?? this.acc,
        speed: speed ?? this.speed,
        source: source ?? this.source,
        bearing: bearing ?? this.bearing,
        activity: activity ?? this.activity,
        isMoving: isMoving ?? this.isMoving,
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

@JsonSerializable()
class Activity extends Equatable {
  static Activity unknown = Activity(
    type: ActivityType.unknown,
    confidence: 100,
  );

  Activity({
    @required this.type,
    @required this.confidence,
  }) : super();

  @override
  List<Object> get props => [
        type,
        confidence,
      ];

  /// Estimated activity type
  final ActivityType type;

  /// Estimate confidence (0-100%)
  final int confidence;

  /// Factory constructor for creating a new `Activity`  instance
  factory Activity.fromJson(Map<String, dynamic> json) => _$ActivityFromJson(json);

  @JsonKey(ignore: true)
  bool get isMoving => !const [ActivityType.unknown, ActivityType.still].contains(type);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$ActivityToJson(this);

  Activity cloneWith({
    double acc,
    SourceType source,
    DateTime timestamp,
  }) =>
      Activity(
        type: acc ?? this.type,
        confidence: confidence ?? this.confidence,
      );
}

enum ActivityType {
  still,
  on_foot,
  walking,
  running,
  unknown,
  on_bicycle,
  in_vehicle,
}

String translateActivityType(ActivityType type) {
  switch (type) {
    case ActivityType.still:
      return "I ro";
    case ActivityType.on_foot:
      return "Til fots";
    case ActivityType.walking:
      return "Går";
    case ActivityType.running:
      return "Løper";
    case ActivityType.on_bicycle:
      return "På sykkel";
    case ActivityType.in_vehicle:
      return "I bil";
    case ActivityType.unknown:
    default:
      return "Ukjent";
  }
}
