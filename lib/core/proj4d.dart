import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// A class representing a geographic reference ellipsoid
/// (or more correctly an oblate spheroid),
/// used to model the shape of the surface of the earth.
///
/// Based on [Ellipsoid.java] in https://github.com/locationtech/proj4j
class Ellipsoid extends Equatable {
  /// Ellipsoid used by World Geodetic System released in 1984 (WGS84)
  static final Ellipsoid wgs84 = Ellipsoid.reciprocal("WGS84", 6378137.0, 298.257223563, "WGS84");

  /// Ellipsoid used by Geodetic Reference System released in 1980 (GRS80)
  static final Ellipsoid grs80 = Ellipsoid.reciprocal("GRS80", 6378137.0, 298.257222101, "GRS 1980 (IUGG, 1980)");

  /// Supported ellipsoids
  static final ellipsoids = [Ellipsoid.wgs84];

  final String name;
  final String shortName;
  final double equatorRadius;
  final double poleRadius;
  final double eccentricity;
  final double eccentricitySquared;

  Ellipsoid._internal(
    this.shortName, {
    this.name,
    this.equatorRadius = 1.0,
    this.poleRadius = 1.0,
    this.eccentricity = 1.0,
    this.eccentricitySquared = 1.0,
  });

  @override
  List<Object> get props => [
        shortName,
        name,
        equatorRadius,
        poleRadius,
        eccentricity,
        eccentricitySquared,
      ];

  factory Ellipsoid.polar(
    String shortName,
    double equatorRadius,
    double poleRadius,
    String name,
  ) {
    final eccentricity2 = 1.0 - (poleRadius * poleRadius) / (equatorRadius * equatorRadius);
    return Ellipsoid._internal(
      shortName,
      equatorRadius: equatorRadius,
      poleRadius: poleRadius,
      eccentricity: math.sqrt(eccentricity2),
      eccentricitySquared: eccentricity2,
      name: name ?? shortName,
    );
  }

  factory Ellipsoid.reciprocal(
    String shortName,
    double equatorRadius,
    double reciprocalFlattening,
    String name,
  ) {
    final double flattening = 1.0 / reciprocalFlattening;
    final eccentricitySquared = (2 * flattening) - (flattening * flattening);
    return Ellipsoid._internal(
      shortName,
      equatorRadius: equatorRadius,
      poleRadius: equatorRadius * math.sqrt(1.0 - eccentricitySquared),
      eccentricity: math.sqrt(eccentricitySquared),
      eccentricitySquared: eccentricitySquared,
      name: name ?? shortName,
    );
  }

  bool isEqual(Ellipsoid e, double e2Tolerance) {
    if (equatorRadius == e.equatorRadius) {
      return (eccentricitySquared - e.eccentricitySquared).abs() <= e2Tolerance;
    }
    return false;
  }
}

/// A class representing a geodetic datum.
///
/// Based on [Datum.java] in https://github.com/locationtech/proj4j
class Datum extends Equatable {
  /// Ellipsoid E2 tolerance
  static const tolerance = 0.000000000050;

  /// Datum used by World Geodetic System released in 1984 (WGS84)
  static final wgs84 = Datum.from3params("WGS84", 0, 0, 0, Ellipsoid.wgs84, "WGS84");

  ///
  final String code;
  final String name;
  final Ellipsoid ellipsoid;
  final List<double> _transform;

  Datum._internal(
    this.code,
    this.name,
    this.ellipsoid,
    this._transform,
  );

  @override
  List<Object> get props => [
        code,
        name,
        ellipsoid,
        _transform,
      ];

  /// Create Datum with 3-param transform
  factory Datum.from3params(
    String code,
    double deltaX,
    double deltaY,
    double deltaZ,
    Ellipsoid ellipsoid,
    String name,
  ) {
    return Datum._internal(code, name, ellipsoid, [deltaX, deltaY, deltaZ]);
  }

  /// Create Datum with 7param transform
  factory Datum.from7params(
    String code,
    double deltaX,
    double deltaY,
    double deltaZ,
    double rx,
    double ry,
    double rz,
    double mbf,
    Ellipsoid ellipsoid,
    String name,
  ) {
    var transform = Datum._prepareTransform([deltaX, deltaY, deltaZ, rx, ry, rz]);
    return Datum._internal(code, name, ellipsoid, transform);
  }

  static List<double> _prepareTransform(List<double> transform) {
    if (transform != null && transform.length > 3) {
      transform[3] *= ProjMath.SECONDS_TO_RAD;
      transform[4] *= ProjMath.SECONDS_TO_RAD;
      transform[5] *= ProjMath.SECONDS_TO_RAD;
      transform[6] = transform[6] / ProjMath.MILLION + 1.0;
    }
    return transform;
  }

  /// Get datum transform type supported by this datum
  DatumTransformType getTransformType() {
    if (Ellipsoid.wgs84 == ellipsoid || Ellipsoid.grs80 == ellipsoid) {
      if (_transform == null) return DatumTransformType.IsWGS84;

      if (ProjMath.isIdentity(_transform)) return DatumTransformType.IsWGS84;
    }

    if (_transform == null) return DatumTransformType.IsUNKNOWN;
    if (_transform.length == 3) return DatumTransformType.Is3PARAM;
    if (_transform.length == 7) return DatumTransformType.Is7PARAM;

    return DatumTransformType.IsUNKNOWN;
  }

  /// Test if transform to WGS84 is available
  bool hasTransformToWGS84() {
    final type = getTransformType();
    return [
      DatumTransformType.Is3PARAM,
      DatumTransformType.Is7PARAM,
    ].contains(type);
  }

  /// Get transform matrix
  List<double> getTransformToWGS84() {
    return List.unmodifiable(_transform);
  }

  @override
  operator ==(Object o) {
    if (o is Datum) {
      if (getTransformType() == o.getTransformType()) {
        if (ellipsoid.isEqual(o.ellipsoid, tolerance)) {
          if (hasTransformToWGS84()) {
            return IterableEquality().equals(_transform, o._transform);
          }
        }
      }
    }
    return false;
  }

  @override
  int get hashCode => super.hashCode;

  /// Transform from geocentric to WGS84 coordinates
  ProjCoordinate toWgs84(ProjCoordinate coord) {
    var pOut = ProjCoordinate.empty;
    if (_transform.length == 3) {
      pOut = ProjCoordinate(
        coord.x + _transform[0],
        coord.y + _transform[1],
        coord.z + _transform[2],
      );
    } else if (_transform.length == 7) {
      var dxBF = _transform[0];
      var dyBF = _transform[1];
      var dzBF = _transform[2];
      var rxBF = _transform[3];
      var ryBF = _transform[4];
      var rzBF = _transform[5];
      var mBF = _transform[6];

      var xOut = mBF * (coord.x - rzBF * coord.y + ryBF * coord.z) + dxBF;
      var yOut = mBF * (rzBF * coord.x + coord.y - rxBF * coord.z) + dyBF;
      var zOut = mBF * (-ryBF * coord.x + rxBF * coord.y + coord.z) + dzBF;
      pOut = ProjCoordinate(
        xOut,
        yOut,
        zOut,
      );
    }
    return pOut;
  }

  /// Transform from WGS84 datum to geocentric coordinates
  ProjCoordinate toGeocentric(ProjCoordinate coord) {
    var pOut = ProjCoordinate.empty;
    if (_transform.length == 3) {
      pOut = ProjCoordinate(
        coord.x - _transform[0],
        coord.y - _transform[1],
        coord.z - _transform[2],
      );
    } else if (_transform.length == 7) {
      var dxBF = _transform[0];
      var dyBF = _transform[1];
      var dzBF = _transform[2];
      var rxBF = _transform[3];
      var ryBF = _transform[4];
      var rzBF = _transform[5];
      var mBF = _transform[6];

      var xTmp = (coord.x - dxBF) / mBF;
      var yTmp = (coord.y - dyBF) / mBF;
      var zTmp = (coord.z - dzBF) / mBF;

      pOut = ProjCoordinate(
        xTmp + rzBF * yTmp - ryBF * zTmp,
        -rzBF * xTmp + yTmp + rxBF * zTmp,
        ryBF * xTmp - rxBF * yTmp + zTmp,
      );
    }
    return pOut;
  }
}

/// Supported datum transforms
enum DatumTransformType { IsWGS84, Is3PARAM, Is7PARAM, IsUNKNOWN }

/// Stores a the coordinates for a position defined relative to some [CoordinateReferenceSystem]
///
/// Based on [ProjCoordinate.java] in https://github.com/locationtech/proj4j
class ProjCoordinate extends Equatable {
  static const decimalFormatPattern = '0.0###############';
  static final decimalFormat = NumberFormat(decimalFormatPattern);

  /// The x-ordinate for this point.
  final double x;

  /// The y-ordinate for this point.
  final double y;

  /// The z-ordinate for this point.
  final double z;

  static final empty = ProjCoordinate(double.nan, double.nan, double.nan);

  bool get isValidLon => x != null && (x >= -180.0 && x <= 180.0);
  bool get isValidLat => y != null && (y >= -85.05112878 && y <= 85.05112878);

  /// Validate coordinates as lat and lon
  ///
  /// Exact limits, as specified by EPSG:900913 / EPSG:3785 / OSGEO:41001
  ///
  bool get isValidLatLng => isValidLon && isValidLat;

  ProjCoordinate(
    this.x,
    this.y,
    this.z,
  );

  @override
  List<Object> get props => [x, y, z];

  factory ProjCoordinate.from2D(double x, double y) => ProjCoordinate(x, y, double.nan);

  ProjCoordinate toRadians() {
    return ProjCoordinate(ProjMath.degToRad(x), ProjMath.degToRad(y), z);
  }

  ProjCoordinate toDegrees() {
    return ProjCoordinate(ProjMath.radToDeg(x), ProjMath.radToDeg(y), z);
  }
}

/// Coordinate system unit base class
///
/// Based on [Unit.java] in https://github.com/locationtech/proj4j
class ProjUnit {
  final String name;
  final String plural;
  final String abbreviation;
  final double value;

  static final degree = ProjUnit._internal('degree', 'degress', 'deg', 1.0);
  static final metres = ProjUnit._internal('metre', 'metres', 'm', 1.0);

  ProjUnit._internal(this.name, this.plural, this.abbreviation, this.value);

  double toBase(double number) {
    return number * value;
  }

  double fromBase(double number) {
    return number / value;
  }
}

/// Projection math utility class
///
/// Based on [ProjectionMath.java] in https://github.com/locationtech/proj4j
class ProjMath {
  /// Constant for converting degrees to radians (DTR)
  static const double DTR = math.pi / 180.0;

  /// Constant for converting radians to degrees (RTD)
  static const double RTD = 180.0 / math.pi;

  /// SECONDS_TO_RAD = Pi/180/3600
  static const double SECONDS_TO_RAD = 4.84813681109535993589914102357e-6;
  static const double MILLION = 1000000.0;
  static const double TWO_PI = math.pi * 2.0;
  static const double HALF_PI = math.pi / 2.0;

  /// Tests whether the datum parameter-based transform is the
  /// identity transform. If true datum transformation can be short-circuited,
  /// avoiding some loss of numerical precision.
  static bool isIdentity(List<double> transform) {
    for (int i = 0; i < transform.length; i++) {
      // scale factor will normally be 1 for an identity transform
      if (i == 6) {
        if (transform[i] != 1.0 && transform[i] != 0.0) return false;
      } else if (transform[i] != 0.0) return false;
    }
    return true;
  }

  static double asin(double v) {
    if (v.abs() > 1.0) return v < 0.0 ? -math.pi / 2 : math.pi / 2;
    return math.asin(v);
  }

  static double acos(double v) {
    if (v.abs() > 1.0) return v < 0.0 ? math.pi : 0.0;
    return math.acos(v);
  }

  static double degToRad(double degrees) {
    return degrees * math.pi / 180.0;
  }

  static double radToDeg(double angle) {
    return angle * 180.0 / math.pi;
  }

  static double normalizeLatitudeInRadians(double angle) {
    if (double.infinity == angle || double.nan == angle) {
      throw "Infinite or NaN latitude";
    }
    while (angle > HALF_PI) angle -= math.pi;
    while (angle < -HALF_PI) angle += math.pi;
    return angle;
  }

  /// Normalize longitude within valid range [-180, 180]
  static double normalizeLongitudeInDegress(double angle) {
    if (double.infinity == angle || double.nan == angle) {
      throw "Infinite or NaN longitude";
    }

    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }

  /// Normalize longitude in radions within valid range [-2PI,2PI]
  static double normalizeLongitudeInRadians(double angle) {
    if (double.infinity == angle || double.nan == angle) {
      throw "Infinite or NaN longitude";
    }
    while (angle > math.pi) angle -= TWO_PI;
    while (angle < -math.pi) angle += TWO_PI;
    return angle;
  }

  static const double C00 = 1.0;
  static const double C02 = .25;
  static const double C04 = .046875;
  static const double C06 = .01953125;
  static const double C08 = .01068115234375;
  static const double C22 = .75;
  static const double C44 = .46875;
  static const double C46 = .01302083333333333333;
  static const double C48 = .00712076822916666666;
  static const double C66 = .36458333333333333333;
  static const double C68 = .00569661458333333333;
  static const double C88 = .3076171875;
  static const int MAX_ITER = 10;

  static List<double> enfn(double es) {
    double t;
    List<double> en = List.filled(5, 0);
    en[0] = C00 - es * (C02 + es * (C04 + es * (C06 + es * C08)));
    en[1] = es * (C22 - es * (C04 + es * (C06 + es * C08)));
    en[2] = (t = es * es) * (C44 - es * (C46 + es * C48));
    en[3] = (t *= es) * (C66 - es * C68);
    en[4] = t * es * C88;
    return en;
  }

  static double mlfn(double phi, double sphi, double cphi, List<double> en) {
    cphi *= sphi;
    sphi *= sphi;
    return en[0] * phi - cphi * (en[1] + sphi * (en[2] + sphi * (en[3] + sphi * en[4])));
  }

  static double mlfnInv(double arg, double es, List<double> en) {
    double s, t, phi, k = 1.0 / (1.0 - es);

    phi = arg;
    for (int i = MAX_ITER; i != 0; i--) {
      s = math.sin(phi);
      t = 1.0 - es * s * s;
      phi -= t = (mlfn(phi, s, math.cos(phi), en) - arg) * (t * math.sqrt(t)) * k;
      if (t.abs() < 1e-11) return phi;
    }
    return phi;
  }

  /// Calculate eucledian distance between two geometric positions.
  ///
  /// This method is significant faster than any
  ///
  /// Relative error for distances:
  /// * less than 5km is ~ 1% at 89˚N, and ~ 0.04 % at 65˚N yields an error between 2cm - 5m
  /// * up to 50km is ~ 10% at 89˚N, and ~ 0.4 % at 65˚N yields an error between 20m - 5km
  ///
  /// Note that latitudes above 89˚N is in practical terms not relevant (less then 110 km from the north pole)
  ///
  /// Returns distance i meters.
  static eucledianDistance(double lat1, double lon1, double lat2, double lon2) {
    final degLen = 110250;
    final x = lat1 - lat2;
    final y = (lon1 - lon2) * math.cos(degToRad(lat2));
    return degLen * math.sqrt(x * x + y * y);
  }

  /// Calculcate coordinates along greater circle given start coordinates, bearing and distance
  ///
  /// Note that the calculation assumes ellipsoid is WGS84.
  static ProjCoordinate calculateEndingGlobalCoordinates(
      double startLat, double startLon, double startBearing, double distance) {
    var mSemiMajorAxis = 6378137.0; //WGS84 major axis
    var mSemiMinorAxis = (1.0 - 1.0 / 298.257223563) * 6378137.0;
    var mFlattening = 1.0 / 298.257223563;
    // double mInverseFlattening = 298.257223563;

    var a = mSemiMajorAxis;
    var b = mSemiMinorAxis;
    var aSquared = a * a;
    var bSquared = b * b;
    var f = mFlattening;
    var phi1 = degToRad(startLat);
    var alpha1 = degToRad(startBearing);
    var cosAlpha1 = math.cos(alpha1);
    var sinAlpha1 = math.sin(alpha1);
    var s = distance;
    var tanU1 = (1.0 - f) * math.tan(phi1);
    var cosU1 = 1.0 / math.sqrt(1.0 + tanU1 * tanU1);
    var sinU1 = tanU1 * cosU1;

    // eq. 1
    var sigma1 = math.atan2(tanU1, cosAlpha1);

    // eq. 2
    var sinAlpha = cosU1 * sinAlpha1;

    var sin2Alpha = sinAlpha * sinAlpha;
    var cos2Alpha = 1 - sin2Alpha;
    var uSquared = cos2Alpha * (aSquared - bSquared) / bSquared;

    // eq. 3
    var A = 1 + (uSquared / 16384) * (4096 + uSquared * (-768 + uSquared * (320 - 175 * uSquared)));

    // eq. 4
    var B = (uSquared / 1024) * (256 + uSquared * (-128 + uSquared * (74 - 47 * uSquared)));

    // iterate until there is a negligible change in sigma
    double deltaSigma;
    var sOverbA = s / (b * A);
    var sigma = sOverbA;
    double sinSigma;
    var prevSigma = sOverbA;
    double sigmaM2;
    double cosSigmaM2;
    double cos2SigmaM2;

    for (;;) {
      // eq. 5
      sigmaM2 = 2.0 * sigma1 + sigma;
      cosSigmaM2 = math.cos(sigmaM2);
      cos2SigmaM2 = cosSigmaM2 * cosSigmaM2;
      sinSigma = math.sin(sigma);
      var cosSignma = math.cos(sigma);

      // eq. 6
      deltaSigma = B *
          sinSigma *
          (cosSigmaM2 +
              (B / 4.0) *
                  (cosSignma * (-1 + 2 * cos2SigmaM2) -
                      (B / 6.0) * cosSigmaM2 * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM2)));

      // eq. 7
      sigma = sOverbA + deltaSigma;

      // break after converging to tolerance
      if ((sigma - prevSigma).abs() < 0.0000000000001) break;

      prevSigma = sigma;
    }

    sigmaM2 = 2.0 * sigma1 + sigma;
    cosSigmaM2 = math.cos(sigmaM2);
    cos2SigmaM2 = cosSigmaM2 * cosSigmaM2;

    var cosSigma = math.cos(sigma);
    sinSigma = math.sin(sigma);

    // eq. 8
    var phi2 = math.atan2(sinU1 * cosSigma + cosU1 * sinSigma * cosAlpha1,
        (1.0 - f) * math.sqrt(sin2Alpha + math.pow(sinU1 * sinSigma - cosU1 * cosSigma * cosAlpha1, 2.0)));

    // eq. 9
    // This fixes the pole crossing defect spotted by Matt Feemster. When a
    // path passes a pole and essentially crosses a line of latitude twice -
    // once in each direction - the longitude calculation got messed up.
    // Using
    // atan2 instead of atan fixes the defect. The change is in the next 3
    // lines.
    // double tanLambda = sinSigma * sinAlpha1 / (cosU1 * cosSigma - sinU1 *
    // sinSigma * cosAlpha1);
    // double lambda = Math.atan(tanLambda);
    var lambda = math.atan2(sinSigma * sinAlpha1, (cosU1 * cosSigma - sinU1 * sinSigma * cosAlpha1));

    // eq. 10
    var C = (f / 16) * cos2Alpha * (4 + f * (4 - 3 * cos2Alpha));

    // eq. 11
    var L =
        lambda - (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cosSigmaM2 + C * cosSigma * (-1 + 2 * cos2SigmaM2)));

    // eq. 12
    // double alpha2 = Math.atan2(sinAlpha, -sinU1 * sinSigma + cosU1 *
    // cosSigma * cosAlpha1);

    // build result
    var latitude = radToDeg(phi2);
    var longitude = startLon + radToDeg(L);

    // if ((endBearing != null) && (endBearing.length > 0)) {
    // endBearing[0] = toDegrees(alpha2);
    // }

    latitude = latitude < -90 ? -90 : latitude;
    latitude = latitude > 90 ? 90 : latitude;
    longitude = longitude < -180 ? -180 : longitude;
    longitude = longitude > 180 ? 180 : longitude;
    return ProjCoordinate(longitude, latitude, 0);
  }
}

/// Represents a projected or geodetic geospatial coordinate system,
/// to which coordinates may be referenced.
///
/// Based on [CoordinateReferenceSystem.java] in https://github.com/locationtech/proj4j
class CoordinateReferenceSystem {
  /// Coordinate system name
  final String name;

  /// Coordinate system parameters
  final List<String> params;

  /// Coordinate system datum
  final Datum datum;

  /// Coordinate system projection
  final Projection projection;

  CoordinateReferenceSystem(
    this.name,
    this.params,
    this.datum,
    this.projection,
  );
}

/// A map projection is a mathematical algorithm
/// for representing a spheroidal surface on a plane.
///
/// Based on [Projection.java] in https://github.com/locationtech/proj4j
abstract class Projection {
  /// The ellipsoid used by this projection
  final Ellipsoid ellipsoid;

  /// Units of this projection. Default is metres, but may be degrees.
  final ProjUnit unit;

  /// The minimum latitude of the bounds of this projection, in radians
  double get minLatitude => _minLatitude;
  double _minLatitude = -ProjMath.HALF_PI;

  /// The maximum latitude of the bounds of this projection, in radians
  double get maxLatitude => _maxLatitude;
  double _maxLatitude = ProjMath.HALF_PI;

  /// The minimum longitude of the bounds of this projection, in radians.
  /// This is relative to the projection centre.
  double get minLongitude => _minLongitude;
  double _minLongitude = -math.pi;

  /// The maximum longitude of the bounds of this projection, in radians.
  /// This is relative to the projection centre.
  double get maxLongitude => _maxLongitude;
  double _maxLongitude = math.pi;

  /// The latitude of the centre of projection, in radians
  /// Same as WKT PROJCS PARAMETER [latitude_of_origin].
  double get projectionLatitude => _projectionLatitude;
  double _projectionLatitude = 0.0;

  /// The longitude of the centre of projection, in radians
  /// Same as WKT PROJCS PARAMETER [central_meridian].
  double get projectionLongitude => _projectionLongitude;
  double _projectionLongitude = 0.0;

  /// The projection scale factor
  double get scaleFactor => _scaleFactor;
  double _scaleFactor = 1.0;

  /// The false Easting of this projection
  /// Same as WKT PROJCS PARAMETER [false_easting].
  double get falseEasting => _falseEasting;
  double _falseEasting = 0.0;

  /// The false Northing of this projection
  /// Same as WKT PROJCS PARAMETER [false_northing].
  double get falseNorthing => _falseNorthing;
  double _falseNorthing = 0.0;

  double get fromMetres => _fromMetres;
  double _fromMetres = 1.0;

  /// The total scale factor = Earth radius * units
  double _totalScale = 0.0;

  /// [falseEasting], adjusted to the appropriate units using [fromMetres]
  double _totalFalseEasting;

  /// [falseNorthing], adjusted to the appropriate units using [fromMetres]
  double _totalFalseNorthing;

  /// Flag for geocentric projection.
  ///
  /// Used with a geographic coordinate system in which the earth
  /// is modeled as a sphere or spheroid in a right-handed XYZ (3D Cartesian)
  /// system measured from the center of the earth
  final bool geocentric;

  Projection(
    this.ellipsoid,
    this.unit, {
    this.geocentric = false,
    double minLatitude,
    double maxLatitude,
    double minLongitude,
    double maxLongitude,
    double projectionLatitude,
    double projectionLongitude,
    double scaleFactor,
    double falseEasting,
    double falseNorthing,
    double fromMetres,
  }) {
    _init(
      minLatitude: minLatitude ?? _minLatitude,
      maxLatitude: maxLatitude ?? _maxLatitude,
      minLongitude: minLongitude ?? _minLongitude,
      maxLongitude: maxLongitude ?? _maxLongitude,
      projectionLatitude: projectionLatitude ?? _projectionLatitude,
      projectionLongitude: projectionLongitude ?? _projectionLongitude,
      scaleFactor: scaleFactor ?? _scaleFactor,
      falseEasting: falseEasting ?? _falseNorthing,
      falseNorthing: falseNorthing ?? _falseNorthing,
      fromMetres: fromMetres ?? _fromMetres,
    );
  }

  /// Tests whether this projection is conformal (preserves local angles).
  bool get conformal => false;

  /// Test if lines of latitude and longitude form a rectangular grid
  bool get rectilinear => false;

  /// Test this projection is using a sphere
  bool get spherical => ellipsoid?.eccentricity == 0;

  /// Initialize the projection. Should be called after setting parameters and before using the projection.
  @protected
  @mustCallSuper
  void _init({
    double minLatitude,
    double maxLatitude,
    double minLongitude,
    double maxLongitude,
    double projectionLatitude,
    double projectionLongitude,
    double scaleFactor,
    double falseEasting,
    double falseNorthing,
    double fromMetres,
  }) {
    _minLatitude = minLatitude ?? _minLatitude;
    _maxLatitude = maxLatitude ?? _maxLatitude;
    _minLongitude = minLongitude ?? _minLongitude;
    _maxLongitude = maxLongitude ?? _maxLongitude;
    _projectionLatitude = projectionLatitude ?? _projectionLatitude;
    _projectionLongitude = projectionLongitude ?? _projectionLongitude;
    _scaleFactor = scaleFactor ?? _scaleFactor;
    _falseEasting = falseEasting ?? _falseEasting;
    _falseNorthing = falseNorthing ?? _falseNorthing;
    _fromMetres = fromMetres ?? _fromMetres;

    _totalScale = ellipsoid.equatorRadius * _fromMetres;
    _totalFalseEasting = _falseEasting * _fromMetres;
    _totalFalseNorthing = _falseNorthing * _fromMetres;
  }

  /// Test if the given coordinate (in degrees) is visible in this projection
  bool inside(double x, double y) {
    x = ProjMath.normalizeLongitudeInRadians((x * ProjMath.DTR - _projectionLongitude));
    y = y * ProjMath.DTR;
    return _minLongitude <= x && x <= _maxLongitude && _minLatitude <= y && y <= _maxLatitude;
  }

  /// Projects a geographic point (in degrees),
  /// producing a projected result in the units of the target coordinate system.
  ProjCoordinate project(ProjCoordinate src) {
    var x = src.x * ProjMath.DTR;
    if (_projectionLongitude != 0) {
      x = ProjMath.normalizeLongitudeInRadians(x - _projectionLongitude);
    }
    var y = src.y * ProjMath.DTR;
    ProjCoordinate dst = _project(x, y);
    if (ProjUnit.degree == unit) {
      // convert radians to decimal degrees (DD)
      x = dst.x * ProjMath.RTD;
      y = dst.y * ProjMath.RTD;
    } else {
      // assume result is in metres
      x = _totalScale * dst.x + _totalFalseEasting;
      y = _totalScale * dst.y + _totalFalseNorthing;
    }
    return ProjCoordinate(x, y, src.z);
  }

  /// Projection algorithm implemented by subclasses
  ProjCoordinate _project(double x, double y);

  /// Projects a projected point (in the units of the target coordinate system),
  /// producing a geographic point (in degrees).
  ProjCoordinate inverse(ProjCoordinate src) {
    var x, y;
    if (ProjUnit.degree == unit) {
      // convert DD to radians
      x = src.x * ProjMath.DTR;
      y = src.y * ProjMath.DTR;
    } else {
      x = (src.x - _totalFalseEasting) / _totalScale;
      y = (src.y - _totalFalseNorthing) / _totalScale;
    }

    ProjCoordinate dst = _inverse(x, y);

    if (dst.x < -math.pi) {
      x = -math.pi;
    } else if (dst.x > math.pi) {
      x = math.pi;
    } else {
      x = dst.x;
    }
    if (_projectionLongitude != 0) {
      x = ProjMath.normalizeLongitudeInRadians(x + _projectionLongitude);
    }
    return ProjCoordinate(x * ProjMath.RTD, dst.y * ProjMath.RTD, src.z);
  }

  /// Inverse-projection algorithm implemented by subclasses
  ProjCoordinate _inverse(double x, double y);
}

/// Transverse Mercator Projection algorithm
///
/// Based on [Projection.java] in https://github.com/locationtech/proj4j
class TransverseMercatorProjection extends Projection {
  /// Default transformation if [zone] == [TRANSVERSE_MERCATOR]
  static const TRANSVERSE_MERCATOR = -1;

  /// Current UTM zone
  int get zone => _zone;
  set zone(int value) => _configure(value, _isSouth);

  /// Default to [TRANSVERSE_MERCATOR] (zone value -1)
  int _zone = TRANSVERSE_MERCATOR;

  /// Indicates whether a Southern Hemisphere UTM zone
  bool get isSouth => _isSouth;
  set isSouth(bool value) => _configure(_zone, value);
  bool _isSouth = false;

  /// Create a default world wide transverse mercator transformation
  /// See https://proj4.org/operations/projections/tmerc.html
  factory TransverseMercatorProjection.ww() => TransverseMercatorProjection._internal(
        Ellipsoid.grs80,
        ProjUnit.metres,
        minLatitude: -ProjMath.HALF_PI,
        maxLatitude: ProjMath.HALF_PI,
      );

  /// Create a UTM transformation for north and south hemispheres
  /// See https://proj4.org/operations/projections/tmerc.html
  factory TransverseMercatorProjection.utm(int zone, bool isSouth) {
    assert(0 <= zone && 60 >= zone, 'Valid zone range is [0,60]');
    return TransverseMercatorProjection._internal(
      Ellipsoid.wgs84,
      ProjUnit.metres,
      zone: zone,
      isSouth: isSouth,
      scaleFactor: 0.9996,
      falseEasting: 500000.0,
      falseNorthing: (isSouth ? 10000000.0 : 0.0),
      projectionLatitude: 0.0,
      projectionLongitude: _toUtmCentralMeridian(zone),
    );
  }

  TransverseMercatorProjection._internal(
    Ellipsoid ellipsoid,
    ProjUnit unit, {
    int zone = TRANSVERSE_MERCATOR,
    bool isSouth = false,
    double minLatitude,
    double maxLatitude,
    double minLongitude,
    double maxLongitude,
    double projectionLatitude,
    double projectionLongitude,
    double scaleFactor,
    double falseEasting,
    double falseNorthing,
  }) : super(
          ellipsoid,
          ProjUnit.metres,
          minLatitude: minLatitude,
          maxLatitude: maxLatitude,
          minLongitude: minLongitude,
          maxLongitude: maxLongitude,
          projectionLatitude: projectionLatitude,
          projectionLongitude: projectionLongitude,
          scaleFactor: scaleFactor,
          falseEasting: falseEasting,
          falseNorthing: falseNorthing,
        ) {
    _configure(zone, isSouth);
  }

  double _esp;
  double _ml0;
  List<double> _en;

  bool isUTM() {
    return 0 <= _zone && 60 >= _zone;
  }

  /// Configure transformation
  void _configure(int zone, bool isSouth) {
    _zone = zone;
    _isSouth = isSouth;
    if (isUTM()) {
      _init(
        falseNorthing: _isSouth ? 10000000.0 : 0.0,
        projectionLongitude: _toUtmCentralMeridian(zone),
      );
    }
    if (spherical) {
      _esp = _scaleFactor;
      _ml0 = 0.5 * _esp;
    } else {
      _en = ProjMath.enfn(ellipsoid.eccentricitySquared);
      _ml0 = ProjMath.mlfn(_projectionLatitude, math.sin(_projectionLatitude), math.cos(_projectionLatitude), _en);
      _esp = ellipsoid.eccentricitySquared / (1.0 - ellipsoid.eccentricitySquared);
    }
  }

  static double _toUtmCentralMeridian(int zone) => (--zone + 0.5) * math.pi / 30.0 - math.pi;

  static const UTM_BANDS = "CDEFGHJKLMNPQRSTUVWXX";

  static String toBand(double lat, {bool isSouth = false}) {
    var bands = "CDEFGHJKLMNPQRSTUVWXX";
    if (isSouth) lat = lat * -1;
    if (-80 <= lat && lat <= 84) {
      return bands[((lat + 80) / 8).floor()];
    }
    throw "UTM is not valid for latitude $lat";
  }

  static int getZoneFromNearestMeridianInDegrees(double longitude) {
    return getZoneFromNearestMeridianInRadians(longitude * ProjMath.DTR);
  }

  static int getZoneFromNearestMeridianInRadians(double longitude) {
    int zone = (ProjMath.normalizeLongitudeInRadians(longitude) + math.pi).floor() * 30 ~/ math.pi + 1;
    return zone < 1
        ? 1
        : zone > 60
            ? 60
            : zone;
  }

  static int getRowFromNearestParallelInDegrees(double latitude) {
    int degrees = (ProjMath.normalizeLatitudeInRadians(latitude) * ProjMath.RTD).toInt();
    if (degrees < -80 || degrees > 84) return 0;
    if (degrees > 80) return 24;
    return ((degrees + 80) / 8 + 3).toInt();
  }

  static const double FC1 = 1.0;
  static const double FC2 = 0.5;
  static const double FC3 = 0.16666666666666666666;
  static const double FC4 = 0.08333333333333333333;
  static const double FC5 = 0.05;
  static const double FC6 = 0.03333333333333333333;
  static const double FC7 = 0.02380952380952380952;
  static const double FC8 = 0.01785714285714285714;

  @override
  ProjCoordinate _project(double x, double y) {
    return spherical ? _sphericalProject(x, y) : _ellipticalProject(x, y);
  }

  /// Perform spherical (Gauss–Krüger) transverse mercator projection,
  /// see spherical form in https://proj4.org/operations/projections/tmerc.html
  ProjCoordinate _sphericalProject(double x, double y) {
    double px, py;
    double cosphi = math.cos(y);
    double b = cosphi * math.sin(x);

    px = _ml0 * _scaleFactor * math.log((1.0 + b) / (1.0 - b));
    double ty = cosphi * math.cos(x) / math.sqrt(1.0 - b * b);
    ty = ProjMath.acos(ty);
    if (y < 0.0) ty = -ty;
    py = _esp * (ty - _projectionLatitude);
    return ProjCoordinate.from2D(
      px,
      py,
    );
  }

  /// Perform elliptical (Gauss–Krüger) transverse mercator projection,
  /// see spherical form in https://proj4.org/operations/projections/tmerc.html
  ProjCoordinate _ellipticalProject(double x, double y) {
    double px, py, al, als, n, t;
    double sinphi = math.sin(y);
    double cosphi = math.cos(y);
    t = cosphi.abs() > 1e-10 ? sinphi / cosphi : 0.0;
    t *= t;
    al = cosphi * x;
    als = al * al;
    al /= math.sqrt(1.0 - ellipsoid.eccentricitySquared * sinphi * sinphi);
    n = _esp * cosphi * cosphi;
    px = _scaleFactor *
        al *
        (FC1 +
            FC3 *
                als *
                (1.0 -
                    t +
                    n +
                    FC5 *
                        als *
                        (5.0 +
                            t * (t - 18.0) +
                            n * (14.0 - 58.0 * t) +
                            FC7 * als * (61.0 + t * (t * (179.0 - t) - 479.0)))));
    py = _scaleFactor *
        (ProjMath.mlfn(y, sinphi, cosphi, _en) -
            _ml0 +
            sinphi *
                al *
                x *
                FC2 *
                (1.0 +
                    FC4 *
                        als *
                        (5.0 -
                            t +
                            n * (9.0 + 4.0 * n) +
                            FC6 *
                                als *
                                (61.0 +
                                    t * (t - 58.0) +
                                    n * (270.0 - 330 * t) +
                                    FC8 * als * (1385.0 + t * (t * (543.0 - t) - 3111.0))))));
    return ProjCoordinate.from2D(
      px,
      py,
    );
  }

  @override
  ProjCoordinate _inverse(double x, double y) {
    return spherical ? _sphericalInverse(x, y) : _ellipticalInverse(x, y);
  }

  /// Perform spherical (Gauss–Krüger) transverse mercator inverse projection,
  /// see spherical form in https://proj4.org/operations/projections/tmerc.html
  ProjCoordinate _sphericalInverse(double x, double y) {
    double px, py;
    double h = math.exp(x / _scaleFactor);
    double g = 0.5 * (h - 1.0 / h);
    h = math.cos(_projectionLatitude + y / _scaleFactor);
    py = ProjMath.asin(math.sqrt((1.0 - h * h) / (1.0 + g * g)));
    if (y < 0) py = -py;
    px = math.atan2(g, h);

    return ProjCoordinate.from2D(
      px,
      py,
    );
  }

  /// Perform elliptical (Gauss–Krüger) transverse mercator inverse projection,
  /// see spherical form in https://proj4.org/operations/projections/tmerc.html
  ProjCoordinate _ellipticalInverse(double x, double y) {
    double px, py, n, con, cosphi, d, ds, sinphi, t;

    py = ProjMath.mlfnInv(_ml0 + y / _scaleFactor, ellipsoid.eccentricitySquared, _en);
    if (y.abs() >= ProjMath.HALF_PI) {
      py = y < 0.0 ? -ProjMath.HALF_PI : ProjMath.HALF_PI;
      px = 0.0;
    } else {
      sinphi = math.sin(py);
      cosphi = math.cos(py);
      t = cosphi.abs() > 1e-10 ? sinphi / cosphi : 0.0;
      n = _esp * cosphi * cosphi;
      con = 1.0 - ellipsoid.eccentricitySquared * sinphi * sinphi;
      d = x * math.sqrt(con) / _scaleFactor;
      con *= t;
      t *= t;
      ds = d * d;
      py -= (con * ds / (1.0 - ellipsoid.eccentricitySquared)) *
          FC2 *
          (1.0 -
              ds *
                  FC4 *
                  (5.0 +
                      t * (3.0 - 9.0 * n) +
                      n * (1.0 - 4.0 * n) -
                      ds *
                          FC6 *
                          (61.0 +
                              t * (90.0 - 252.0 * n + 45.0 * t) +
                              46.0 * n -
                              ds * FC8 * (1385.0 + t * (3633.0 + t * (4095.0 + 1574.0 * t))))));
      px = d *
          (FC1 -
              ds *
                  FC3 *
                  (1.0 +
                      2.0 * t +
                      n -
                      ds *
                          FC5 *
                          (5.0 +
                              t * (28.0 + 24.0 * t + 8.0 * n) +
                              6.0 * n -
                              ds * FC7 * (61.0 + t * (662.0 + t * (1320.0 + 720.0 * t)))))) /
          cosphi;
    }
    return ProjCoordinate.from2D(
      px,
      py,
    );
  }
}

/// Performs coordinate formatting
class CoordinateFormat {
  static const EASTING = "EW";
  static const NORTHTING = "NS";

  /// UTM coordinate pattern
  static final RegExp utm = RegExp(
    r"([1-6]\d)([C-X]+)\s*([NSWE]?\d{1,7}[.]?\d*[NSWE]?\s+[NSWE]?\d{1,7}[.]?\d*[NSWE]?)",
    caseSensitive: false,
  );

  /// Coordinate ordinate pattern
  static final RegExp ordinate = RegExp(
    r"([NSWE]?)([-]?\d+[.]?\d*)([NSWE]?)",
    caseSensitive: false,
  );

  /// Trim '0' from beginning of string and whitespaces on both sides
  static String trim(String value) {
    return value.replaceFirst(RegExp(r'^0+'), '').trim();
  }

  /// Get axis from given labels. Returns 'lat' for northing and 'lon' for easting.
  static String axis(List<String> labels) {
    var axis;
    if (isNorthing(labels)) {
      axis = NORTHTING;
    } else if (isEasting(labels)) {
      axis = EASTING;
    }
    return axis;
  }

  static List<String> labels(Match match) {
    var values = match.groups([1, 3]).toSet().toList();
    values.retainWhere((test) => test.isNotEmpty);
    return values;
  }

  static bool isEasting(List<String> labels) {
    var found = labels.where((test) => test.isNotEmpty && EASTING.contains(test));
    return found.isNotEmpty;
  }

  static bool isNorthing(List<String> labels) {
    var found = labels.where((test) => test.isNotEmpty && NORTHTING.contains(test));
    return found.isNotEmpty;
  }

  static final ddOrdinalFormat = NumberFormat("###.000000")..maximumFractionDigits = 6;
  static String toDD(ProjCoordinate from, {bool withLabels = false}) {
    final northing = ddOrdinalFormat.format(from.y);
    final easting = ddOrdinalFormat.format(from.x);
    return withLabels ? "N$northing E$easting" : "$northing $easting";
  }

  static String toDDM(ProjCoordinate from, {bool withLabels = false}) {
    final northing = _coordToDDM(from.y);
    final easting = _coordToDDM(from.x);
    return withLabels ? "N$northing E$easting" : "$northing $easting";
  }

  static final msOrdinalFormat = NumberFormat("##.0000")..maximumFractionDigits = 6;
  static String _coordToDDM(double coordinate) {
    final northing = ddOrdinalFormat.format(coordinate);
    final ncomps = northing.split('.');
    final dnorth = int.parse(ncomps.first);
    final mnorth = msOrdinalFormat.format((coordinate - dnorth) * 3600 / 60);
    return "$dnorth° $mnorth";
  }

  static final utmOrdinalFormat = NumberFormat("0000000")..maximumFractionDigits = 0;
  static String toUTM(ProjCoordinate from, {int zone = 32, String band = "V", bool withLabels = false}) {
    final northing = utmOrdinalFormat.format(from.y);
    final easting = utmOrdinalFormat.format(from.x);
    return withLabels ? "$zone$band E$easting N$northing" : "$zone$band $easting $northing";
  }

  static ProjCoordinate toLatLng(String coordinate) {
    var row;
    var zone = -1, lat, lon;
    var isSouth = false;
    var isDefault = false;
    var matches = <Match>[];
    var ordinals = HashMap<String, Match>();

    coordinate = coordinate.trim();

    if (!kReleaseMode) print("Search: $coordinate");

    // Is utm?
    var match = utm.firstMatch(coordinate);
    if (match != null) {
      zone = int.parse(match.group(1));
      row = match.group(2).toUpperCase();
      isSouth = 'N'.compareTo(row) > 0;
      coordinate = match.group(3);
      if (!kReleaseMode) print("Found UTM coordinate in grid '$zone$row'");
    }

    // Attempt to map each match to an axis
    coordinate.split(" ").forEach((value) {
      var match = ordinate.firstMatch(value);
      if (match != null) {
        matches.add(match);
        var axis = CoordinateFormat.axis(CoordinateFormat.labels(match));
        // Preserve order
        if (axis != null) {
          if (ordinals.containsKey(axis)) {
            if (!kReleaseMode) print('Found same axis label on both ordinals');
            ordinals.clear();
          } else {
            ordinals[axis] = match;
          }
        }
      }
    });

    // No axis labels found?
    if (ordinals.length == 0 && matches.length == 2) {
      // Assume default order {lat, lon} is entered
      isDefault = true;
      ordinals[CoordinateFormat.NORTHTING] = matches.first;
      ordinals[CoordinateFormat.EASTING] = matches.last;
      if (!kReleaseMode) print("Assumed default order {NORTHING, EASTING} ");
    } else if (ordinals.length == 1) {
      // One axis label found, try to infer the other
      matches.forEach((match) {
        if (!ordinals.containsValue(match)) {
          // Infer missing axis
          var first = ordinals.values.first;
          var axis = (CoordinateFormat.NORTHTING == ordinals.keys.first
              ? CoordinateFormat.EASTING
              : CoordinateFormat.NORTHTING);
          ordinals[axis] = match;
          if (!kReleaseMode) print("Inferred axis '$axis' from ordinal: '${first.group(0)}'");
        }
      });
    }

    // Search for address?
    if (ordinals.length == 2) {
      lat = double.tryParse(CoordinateFormat.trim(ordinals[CoordinateFormat.NORTHTING].group(2)));
      lon = double.tryParse(CoordinateFormat.trim(ordinals[CoordinateFormat.EASTING].group(2)));
      if (zone > 0) {
        var proj = TransverseMercatorProjection.utm(zone, isSouth);
        var dst = proj.inverse(isDefault ? ProjCoordinate.from2D(lat, lon) : ProjCoordinate.from2D(lon, lat));
        lon = dst.x;
        lat = dst.y;
      }
    }
    return lat != null && lon != null ? ProjCoordinate.from2D(lat, lon) : null;
  }
}
