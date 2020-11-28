import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:meta/meta.dart';

import 'TrackingSource.dart';

abstract class TrackingTrack extends EntityObject<Map<String, dynamic>> {
  TrackingTrack({
    @required String id,
    @required this.status,
    @required this.source,
    @required this.positions,
  }) : super(id, fields: [
          status,
          source,
          positions,
        ]);

  final TrackingSource source;
  final TrackStatus status;
  final List<Position> positions;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => positions?.isEmpty == true;

  TrackingTrack cloneWith({
    String id,
    TrackStatus status,
    TrackingSource source,
    List<Position> positions,
  });

  /// Truncate to number of points and return new [TrackingTrack] instance
  TrackingTrack truncate(int count);
}

enum TrackStatus { attached, detached }

String translateTrackStatus(TrackStatus status) {
  switch (status) {
    case TrackStatus.attached:
      return "Tilknyttet";
    case TrackStatus.detached:
    default:
      return "Ikke tilknyttet";
  }
}
