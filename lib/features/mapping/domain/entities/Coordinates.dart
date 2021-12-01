

import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/domain/models/core.dart';

class Coordinates extends ValueObject<List<double?>> {
  Coordinates({
    required this.lat,
    required this.lon,
    this.alt,
  }) : super([lat, lon, alt]);

  final double? lat;
  final double? lon;
  final double? alt;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => _isEmpty(lat) || _isEmpty(lon);

  bool _isEmpty(double? value) => value == 0 || value == null;

  /// Factory constructor for creating a new `Point`  instance
  factory Coordinates.fromJson(List<dynamic>? json) => Coordinates(
        lat: latFromJson(json),
        lon: lonFromJson(json),
        alt: altFromJson(json),
      );

  /// Declare support for serialization to JSON.
  /// GeoJSON specifies longitude at index 0,
  /// latitude at index 1 and altitude at index 2,
  /// see https://tools.ietf.org/html/rfc7946#section-3.1.1
  List<double?> toJson() => [lon, lat, if (alt != null) alt];
}
