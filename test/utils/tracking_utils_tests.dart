import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';

import '../mock/device_service_mock.dart';
import '../mock/personnel_service_mock.dart';
import '../mock/tracking_service_mock.dart';
import '../mock/unit_service_mock.dart';

void main() {
  // Initial tracking with status created
  final t0 = TrackingBuilder.create();

  // Initial timestamp is epoch
  final ts1 = DateTime.fromMillisecondsSinceEpoch(0);

  // Second timestamp
  final ts2 = ts1.add(Duration(minutes: 1));

  // Third timestamp
  final ts3 = ts2.add(Duration(minutes: 1));

  // First position is (1,1)
  final p1 = Position.timestamp(
    lat: 1,
    lon: 1,
    source: PositionSource.manual,
    timestamp: ts1,
  );

  // Second position is (3,3)
  final p2 = Position.timestamp(
    lat: 3,
    lon: 3,
    source: PositionSource.manual,
    timestamp: ts2,
  );

  // Second position is (5,5)
  final p3 = Position.timestamp(
    lat: 5,
    lon: 5,
    source: PositionSource.manual,
    timestamp: ts3,
  );

  // Arithmetic mean of (p1,p2)
  final p12 = Point.fromCoords(
    lat: 2,
    lon: 2,
  );

  // Arithmetic mean of (p2,p3)
  final p23 = Point.fromCoords(
    lat: 4,
    lon: 4,
  );

  // Device 1 with first position
  final d1p1 = DeviceBuilder.create(position: p1);

  // Device 1 with second position
  final d1p2 = d1p1.copyWith(position: p2);

  // Device 1 with third position
  final d1p3 = d1p1.copyWith(position: p3);

  // Device 2 with second position
  final d2p2 = DeviceBuilder.create(position: p2);

  // Device 2 with third position
  final d2p3 = d2p2.copyWith(position: p3);

  // Source 1 with first position
  final s1p1 = PositionableSource.from(d1p1);

  // Source 1 with second position
  final s1p2 = PositionableSource.from(d1p2);

  // Source 1 with third position
  final s1p3 = PositionableSource.from(d1p3);

  // Source 2 with second position
  final s2p2 = PositionableSource.from(d2p2);

  // Source 2 with third position
  final s2p3 = PositionableSource.from(d2p3);

  // Distance between p1 and p2
  final dst12 = ProjMath.eucledianDistance(
    p1.lat,
    p1.lon,
    p2.lat,
    p2.lon,
  );

  // Distance between p2 and p3
  final dst23 = ProjMath.eucledianDistance(
    p2.lat,
    p2.lon,
    p3.lat,
    p3.lon,
  );

  // Distance between p1 and p3
  final dst13 = ProjMath.eucledianDistance(
    p1.lat,
    p1.lon,
    p3.lat,
    p3.lon,
  );

  // Total distance (p1,p2) + (p2,p3)
  final dst1223 = dst12 + dst23;

  // Distance p12 and p23
  final dst1223a = ProjMath.eucledianDistance(
    p12.lat,
    p12.lon,
    p23.lat,
    p23.lon,
  );

  // Effort between p1 and p2
  final eft12 = ts2.difference(ts1);

  // Effort between p2 and p3
  final eft23 = ts3.difference(ts2);

  // Effort between p1 and p3
  final eft13 = ts3.difference(ts1);

  // Total effort (p1,p2) + (p2,p3)
  final eft1223 = eft12 + eft23;

  // Effort between p12 and p23
  final eft1223a = Duration(milliseconds: (eft12 + eft23).inMilliseconds ~/ 2);

  // Speed between p1 and p2
  final spd12 = dst12 / eft12.inSeconds;

  // Speed between p1 and p3
  final spd13 = dst13 / eft13.inSeconds;

  // Average speed (p1,p2) + (p2,p3)
  final spd1223 = dst1223 / eft1223.inSeconds;

  // Average speed between p12 and p23
  final spd1223a = dst1223a / eft1223a.inSeconds;

  test('SHOULD create tracking from unit', () {
    // Arrange
    final unit = UnitBuilder.create(tuuid: Uuid().v4());

    // Act - two identical (source,position)-pairs: s1p2
    final t1 = TrackingUtils.create(unit, sources: [s1p1, s1p2, s1p2]);

    // Assert
    expect(t1.sources.length, 1, reason: "SHOULD contain 1 source");
    expect(t1.sources.first.uuid, s1p1.uuid, reason: "SHOULD contain source ${s1p1.uuid}");
    expect(t1.tracks.length, 1, reason: "SHOULD contain 1 track");
    expect(t1.tracks.first.positions.length, 2, reason: "SHOULD contain 2 position");
    expect(t1.position.geometry, equals(p2.geometry), reason: "SHOULD be p2");
    expect(t1.history.length, 1, reason: "SHOULD be 1");
    expect(t1.history.last.geometry, equals(p2.geometry), reason: "SHOULD be p2");
    expect(t1.distance, 0.0, reason: "SHOULD be 0.0");
    expect(t1.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
    expect(t1.speed, 0.0, reason: "SHOULD be 0.0");
  });

  test('SHOULD create tracking from personnel', () {
    // Arrange
    final personnel = PersonnelBuilder.create(tuuid: Uuid().v4());

    // Act - with two identical (source,position)-pairs: s1p2
    final t1 = TrackingUtils.create(personnel, sources: [s1p1, s1p2, s1p2, s1p3]);

    // Assert
    expect(t1.sources.length, 1, reason: "SHOULD contain 1 source");
    expect(t1.sources.first.uuid, s1p1.uuid, reason: "SHOULD contain source ${s1p1.uuid}");
    expect(t1.tracks.length, 1, reason: "SHOULD contain 1 track");
    expect(t1.tracks.first.positions.length, 3, reason: "SHOULD contain 3 positions");
    expect(t1.position.geometry, equals(p3.geometry), reason: "SHOULD be p3");
    expect(t1.history.length, 1, reason: "SHOULD be 1");
    expect(t1.history.last.geometry, equals(p3.geometry), reason: "SHOULD be p3");
    expect(t1.distance, 0.0, reason: "SHOULD be 0.0");
    expect(t1.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
    expect(t1.speed, 0.0, reason: "SHOULD be 0.0");
  });

  group('WHEN tracking is empty', () {
    // Arrange
    final personnel = PersonnelBuilder.create(tuuid: Uuid().v4());

    // Act
    final t1 = TrackingUtils.create(personnel);

    test('[t1] tracking status is created', () {
      // Assert
      expect(t1.status, TrackingStatus.ready, reason: "SHOULD be empty");
    });

    test('[t2] tracking history is updated with manual position', () {
      // Act
      final t2 = TrackingUtils.calculate(t1, position: p1, status: TrackingStatus.tracking);
      final t3 = TrackingUtils.calculate(t2, position: p2, status: TrackingStatus.tracking);

      // Assert t2
      expect(t2.status, TrackingStatus.ready, reason: "SHOULD be empty");
      expect(t2.position.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t2.history.length, 1, reason: "SHOULD be 1");
      expect(t2.history.first.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t2.distance, 0.0, reason: "SHOULD be 0.0");
      expect(t2.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
      expect(t2.speed, 0.0, reason: "SHOULD be 0.0");

      // Assert t3
      expect(t3.status, TrackingStatus.ready, reason: "SHOULD be empty");
      expect(t3.position.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t3.history.length, 2, reason: "SHOULD be 1");
      expect(t3.history.first.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t3.distance, dst12, reason: "SHOULD be $dst12");
      expect(t3.effort, eft12, reason: "SHOULD be $eft12");
      expect(t3.speed, spd12, reason: "SHOULD be $spd12");
    });
  });

  group('WHEN tracking contains as single source', () {
    // Act
    final t1 = TrackingUtils.attachAll(t0, [s1p1]);

    test('[t1] tracking status is tracking', () {
      // Assert
      expect(t1.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
    });

    test('[s1] track status is attached', () {
      // Assert
      expect(t1.tracks.isNotEmpty, isTrue, reason: "SHOULD not be empty");
      expect(t1.tracks.first.status, TrackStatus.attached, reason: "SHOULD be attached");
    });

    test('[t1] tracking position should be p1 initially', () {
      // Assert
      expect(t1.position.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t1.history.length, 1, reason: "SHOULD be 1");
      expect(t1.history.last.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t1.distance, 0.0, reason: "SHOULD be 0.0");
      expect(t1.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
      expect(t1.speed, 0.0, reason: "SHOULD be 0.0");
    });

    test('and [s1p2, s1p3] is attached to [t2], tracking is calculated from p1 to p3 directly', () {
      // ACT - Concatenate positions in same track
      //
      // Distance will be calculated from p1 to
      // p3 since each calculation is based on
      // the position from previous calculation
      // (using tail - 2).
      //
      final t2 = TrackingUtils.attachAll(t1, [s1p2, s1p3]);

      // Assert
      expect(t2.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t2.position.geometry, equals(p3.geometry), reason: "SHOULD be p3");
      expect(t2.sources.length, 1, reason: "SHOULD contain 1 source");
      expect(t2.tracks.length, 1, reason: "SHOULD contain 1 track");
      expect(t2.tracks.first.positions.length, 3, reason: "SHOULD contain 3 positions");
      expect(t2.history.length, 2, reason: "SHOULD be 2");
      expect(t2.history.last.geometry, equals(p3.geometry), reason: "SHOULD be p3");
      expect(t2.distance, dst13, reason: "SHOULD be $dst13");
      expect(t2.effort, eft13, reason: "SHOULD be $eft13");
      expect(t2.speed, spd13, reason: "SHOULD be $spd13");
    });

    test('[t2] is attached as [s1p2] + [s1p3], tracking is calculated as (p1,p2) + (p2,p3)', () {
      // ACT - Add two positions to same track in concession
      //
      // Distance will be calculated as the
      // sum of (p1,p2) + (p2, p3)
      final t2 = TrackingUtils.attachAll(t1, [s1p2]);
      final t3 = TrackingUtils.attachAll(t2, [s1p3]);

      // Assert
      expect(t3.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t3.position.geometry, equals(p3.geometry), reason: "SHOULD be p3");
      expect(t3.sources.length, 1, reason: "SHOULD contain 1 source");
      expect(t3.tracks.length, 1, reason: "SHOULD contain 1 track");
      expect(t3.tracks.first.positions.length, 3, reason: "SHOULD contain 3 positions");
      expect(t3.history.length, 3, reason: "SHOULD be 3");
      expect(t3.history.last.geometry, equals(p3.geometry), reason: "SHOULD be p3");
      expect(t3.distance, dst1223, reason: "SHOULD be $dst1223");
      expect(t3.effort, eft1223, reason: "SHOULD be $eft1223");
      expect(t3.speed, spd1223, reason: "SHOULD be $spd1223");
    });

    test('and [s1p1] is detached from [t2], track should be detached and tracking paused', () {
      // ACT
      final t2 = TrackingUtils.detachAll(t1, [s1p1.uuid]);

      // Assert
      expect(t2.tracks.isNotEmpty, isTrue, reason: "SHOULD not be empty");
      expect(t2.tracks.first.status, TrackStatus.detached, reason: "SHOULD be detached");
      expect(t2.position.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t2.status, TrackingStatus.ready, reason: "SHOULD be empty");
    });

    test('and [s1p1] is replaced with [s1p2] in [t2], position is added to existing track', () {
      // ACT
      final t2 = TrackingUtils.replaceAll(t1, [s1p2]);

      // Assert
      expect(t2.position.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t2.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t2.tracks.isNotEmpty, isTrue, reason: "SHOULD not be empty");
      expect(t2.tracks.length, 1, reason: "SHOULD contain 1 track");
      expect(t2.tracks.last.status, TrackStatus.attached, reason: "SHOULD be attached");
      expect(t2.tracks.last.positions.length, 2, reason: "SHOULD contain 2 positions");
      expect(t2.history.length, 2, reason: "SHOULD be 2");
      expect(t2.history.last.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t2.distance, dst12, reason: "SHOULD be $dst13");
      expect(t2.effort, eft12, reason: "SHOULD be $eft12");
      expect(t2.speed, spd12, reason: "SHOULD be $spd12");
    });

    test('and [s1p1] is deleted from [t2], track should be deleted and tracking paused', () {
      // ACT
      final t2 = TrackingUtils.deleteAll(t1, [s1p1.uuid]);

      // Assert
      expect(t2.tracks.isEmpty, isTrue, reason: "SHOULD be empty");
      expect(t2.position.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t2.status, TrackingStatus.ready, reason: "SHOULD be empty");
    });

    test('and [s1p1] is re-attached in [t2], old track should be re-attached and tracking resumed', () {
      // ACT
      final t2 = TrackingUtils.detachAll(t1, [s1p1.uuid]);
      final t3 = TrackingUtils.attachAll(t2, [s1p2]);

      // Assert
      expect(t3.tracks.isNotEmpty, isTrue, reason: "SHOULD not be empty");
      expect(t3.tracks.first.status, TrackStatus.attached, reason: "SHOULD be attached");
      expect(t3.position.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t3.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
    });
  });

  group('WHEN tracking multiple devices', () {
    // Act
    final t1 = TrackingUtils.attachAll(t0, [s1p1, s2p2]);

    test('and [s1p1] and [s2p2] is attached to [t1], arithmetic mean between p1 and p2 is calculated', () {
      // Assert
      expect(t1.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t1.position.geometry, equals(p12), reason: "SHOULD be p12");
      expect(t1.sources.length, 2, reason: "SHOULD contain 2 sources");
      expect(t1.tracks.length, 2, reason: "SHOULD contain 2 tracks");
      expect(t1.tracks.first.positions.length, 1, reason: "SHOULD contain 1 position");
      expect(t1.tracks.first.positions.last.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t1.tracks.last.positions.length, 1, reason: "SHOULD contain 1 position");
      expect(t1.tracks.last.positions.last.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t1.history.length, 1, reason: "SHOULD be 1");
      expect(t1.history.last.geometry, equals(p12), reason: "SHOULD be p12");
      expect(t1.distance, 0.0, reason: "SHOULD be 0.0");
      expect(t1.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
      expect(t1.speed, 0.0, reason: "SHOULD be 0.0");
    });

    test('and [s1p1, s1p2] and [s2p2, s2p1] is attached to [t2], two arithmetic means are calculated', () {
      // Act
      final t2 = TrackingUtils.attachAll(t1, [s1p2, s2p3]);

      // Assert
      expect(t2.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t2.position.geometry, equals(p23), reason: "SHOULD be p23");
      expect(t2.sources.length, 2, reason: "SHOULD contain 2 sources");
      expect(t2.tracks.length, 2, reason: "SHOULD contain 2 tracks");
      expect(t2.tracks.first.positions.length, 2, reason: "SHOULD contain 2 positions");
      expect(t2.tracks.first.positions.last.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t2.tracks.last.positions.length, 2, reason: "SHOULD contain 2 positions");
      expect(t2.tracks.last.positions.last.geometry, equals(p3.geometry), reason: "SHOULD be p3");
      expect(t2.history.length, 2, reason: "SHOULD be 2");
      expect(t2.history.last.geometry, equals(p23), reason: "SHOULD be p23");
      expect(t2.distance, dst1223a, reason: "SHOULD be $dst1223a");
      expect(t2.effort, eft1223a, reason: "SHOULD be $eft1223a");
      expect(t2.speed, spd1223a, reason: "SHOULD be $spd1223a");
    });

    test('and [t1] is closed, all sources are deleted and tracks detached', () {
      // ACT
      final t2 = TrackingUtils.close(t1);

      // Assert
      expect(t2.sources.isEmpty, isTrue, reason: "SHOULD be empty");
      expect(t2.tracks.isNotEmpty, isTrue, reason: "SHOULD not be empty");
      expect(t2.tracks.first.status, TrackStatus.detached, reason: "SHOULD be attached");
      expect(t2.position.geometry, equals(p12), reason: "SHOULD be p12");
      expect(t2.status, TrackingStatus.closed, reason: "SHOULD be closed");
    });

    test('and [t2] is re-opened, all sources are added and tracks re-attached', () {
      // ACT
      final t2 = TrackingUtils.toggle(t1, true);
      final t3 = TrackingUtils.toggle(t2, false);

      // Assert
      expect(t3.tracks.length, 2, reason: 'SHOULD contain 2 tracks');
      expect(t3.tracks.first.status, TrackStatus.attached, reason: 'SHOULD be attached');
      expect(t3.tracks.last.status, TrackStatus.attached, reason: "SHOULD be attached");
      expect(t3.sources.length, 2, reason: 'SHOULD contain 2 sources');
      expect(t3.position.geometry, equals(p12), reason: 'SHOULD be p12');
      expect(t3.status, TrackingStatus.tracking, reason: 'SHOULD be tracking');
    });
  });

  group('WHEN tracking multiple sources', () {
    // ARRANGE trackable 1 as personnel
    final tbl1 = PersonnelBuilder.create(tuuid: Uuid().v4());
    final tbl1s1 = PositionableSource.from(tbl1, position: p1);
    final tbl1t1 = TrackingUtils.attachAll(TrackingBuilder.create(uuid: tbl1.tracking.uuid), [tbl1s1]);
    final tbl1t1s1 = PositionableSource.from(tbl1, position: tbl1t1.position);

    // ARRANGE trackable 2 as unit
    final tbl2 = UnitBuilder.create(tuuid: Uuid().v4());
    final tbl2s2 = PositionableSource.from(tbl2, position: p2);
    final tbl2t2 = TrackingUtils.attachAll(TrackingBuilder.create(uuid: tbl2.tracking.uuid), [tbl2s2]);
    final tbl2t2s2 = PositionableSource.from(tbl2, position: tbl2t2.position);

    // ACT on two tracking objects
    final t1 = TrackingUtils.attachAll(t0, [tbl1t1s1, tbl2t2s2]);

    test('an arithmetic mean of (p1, p2) is calculated for unit [tbl1t1s1] and personnel [tbl2t2s2]', () {
      // Assert
      expect(t1.status, TrackingStatus.tracking, reason: "SHOULD be tracking");
      expect(t1.position.geometry, equals(p12), reason: "SHOULD be p12");
      expect(t1.sources.length, 2, reason: "SHOULD contain 2 sources");
      expect(t1.tracks.length, 2, reason: "SHOULD contain 2 tracks");
      expect(t1.tracks.first.positions.length, 1, reason: "SHOULD contain 1 position");
      expect(t1.tracks.first.positions.last.geometry, equals(p1.geometry), reason: "SHOULD be p1");
      expect(t1.tracks.last.positions.length, 1, reason: "SHOULD contain 1 position");
      expect(t1.tracks.last.positions.last.geometry, equals(p2.geometry), reason: "SHOULD be p2");
      expect(t1.history.length, 1, reason: "SHOULD be 1");
      expect(t1.history.last.geometry, equals(p12), reason: "SHOULD be p12");
      expect(t1.distance, 0.0, reason: "SHOULD be 0.0");
      expect(t1.effort, Duration.zero, reason: "SHOULD be ${Duration.zero}");
      expect(t1.speed, 0.0, reason: "SHOULD be 0.0");
    });
  });
}
