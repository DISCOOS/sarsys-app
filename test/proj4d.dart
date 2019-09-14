import 'dart:math' as math;
import 'package:SarSys/core/proj4d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/matcher.dart';

void main() {
  /// Set tolerance to 5cm.
  const TOL_M = 0.005;

  double error(ProjCoordinate p, double x, double y) {
    var dx = (p.x - x).abs();
    var dy = (p.y - y).abs();
    return math.max(dx, dy);
  }

  void checkProj(String name, Projection proj, double lon, double lat, double x, double y, double tolerance) {
    var src = ProjCoordinate.from2D(lon, lat);
    var d1 = proj.project(src);
    var e1 = error(d1, x, y);
    expect(e1, lessThan(tolerance), reason: "$name: Project error $e1 outsize tolerance $tolerance");
    var d2 = proj.inverse(d1);
    var e2 = error(d2, lon, lat);
    expect(e2, lessThan(tolerance), reason: "$name: Inverse error $e2 outsize tolerance $tolerance");
    print("$name: Errors {$e1, $e2} within tolerance $tolerance");
  }

  test('PROJ[EPSG:4326 <-> EPSG:32632]', () {
    checkProj(
      'PROJ[EPSG:4326 <-> EPSG:32632]',
      TransverseMercatorProjection.utm(32, false),
      9.0,
      59.0,
      500000.00,
      6540052.02,
      TOL_M,
    );
  });

  test('PROJ[EPSG:4326 <-> EPSG:32633]', () {
    checkProj(
      'PROJ[EPSG:4326 <-> EPSG:32633]',
      TransverseMercatorProjection.utm(33, false),
      15.0,
      59.0,
      500000.00,
      6540052.02,
      TOL_M,
    );
  });

  test('PROJ[EPSG:4326 <-> EPSG:32635]', () {
    checkProj(
      'PROJ[EPSG:4326 <-> EPSG:32635]',
      TransverseMercatorProjection.utm(35, false),
      27.0,
      59.0,
      500000.00,
      6540052.02,
      TOL_M,
    );
  });
}
