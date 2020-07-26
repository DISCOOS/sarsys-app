import 'package:SarSys/core/domain/models/core.dart';
import 'package:meta/meta.dart';

import 'converters.dart';

class Coordinates extends ValueObject<List<double>> {
  Coordinates({
    @required this.lat,
    @required this.lon,
    this.alt,
  }) : super([lat, lon, alt]);

  final double lat;
  final double lon;
  final double alt;

  @override
  List<Object> get props => [
        lat,
        lon,
        alt,
      ];

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => _isEmpty(lat) || _isEmpty(lon);

  bool _isEmpty(double value) => value == 0 || value == null;

  /// Factory constructor for creating a new `Point`  instance
  factory Coordinates.fromJson(List<dynamic> json) => Coordinates(
        lat: latFromJson(json),
        lon: lonFromJson(json),
        alt: altFromJson(json),
      );

  /// Declare support for serialization to JSON
  List<double> toJson() => [lat, lon, if (alt != null) alt];
}
