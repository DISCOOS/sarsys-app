import 'dart:math';

import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Source.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/repositories/tracking_repository.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class TrackingUtils {
  /// Create tracking reference
  static AggregateRef<Tracking> newRef({String tuuid}) => AggregateRef.fromType<Tracking>(
        tuuid ?? Uuid().v4(),
      );

  /// Ensure tracking reference
  static AggregateRef<Tracking> ensureRef<T extends Trackable>(T trackable, {String tuuid}) =>
      trackable?.tracking?.uuid == null
          // Create new ref
          ? newRef(tuuid: tuuid)
          // Use old ref
          : trackable.tracking;

  /// Asserts if [trackable] reference is valid.
  ///
  /// [Trackable]s should contain a tracking reference when
  /// they are created. [TrackingBloc] will use this
  /// reference to create a [Tracking] instance which the
  /// backend will create apriori using the same uuid.
  /// This allows for offline creation of tracking objects
  /// in apps resulting in a better user experience
  static String assertRef<T extends Trackable>(T trackable) {
    final tuuid = trackable.tracking?.uuid;
    if (tuuid == null) {
      throw ArgumentError(
        "${trackable?.tracking?.type ?? typeOf<T>()} is not configured for tracking: AggregateRef is null",
      );
    }
    return tuuid;
  }

  /// Map collection of [aggregates] to list of [Source]s
  ///
  /// The position of [Trackable] aggregates are looked
  /// up in [repo]. This position will be used as
  /// initial position in any [Track]s attached to
  /// [Tracking] by [TrackingUtils.create] or
  /// [TrackingUtils.attach].
  ///
  /// This method includes only [Aggregate] that are
  /// active if [activeOnly] is true (default).
  ///
  static List<PositionableSource<Aggregate>> toSources<T extends Aggregate>(
    Iterable<T> aggregates,
    TrackingRepository repo, {
    bool activeOnly = true,
  }) =>
      (aggregates ?? [])
          .where((aggregate) => !activeOnly || isSourceActive(aggregate))
          .map((aggregate) => PositionableSource.from<T>(
                aggregate,
                position: _toPosition(aggregate, repo),
              ))
          .toList();

  static Position _toPosition(aggregate, TrackingRepository repo) {
    return aggregate is Trackable && repo.containsKey(aggregate.tracking?.uuid)
        ? repo[aggregate.tracking.uuid].position
        : toPosition(
            aggregate,
          );
  }

  /// Gets position from aggregate if it is [Positionable]
  static Position toPosition<T>(T aggregate) => aggregate is Positionable ? aggregate.position : null;

  /// Check if source is active.
  ///
  /// If [source] is not a supported
  /// type an [ArgumentError] is thrown
  static bool isSourceActive(Aggregate source) {
    if (source is Device) {
      return DeviceStatus.Available == source.status;
    } else if (source is Unit) {
      return UnitStatus.Retired != source.status;
    } else if (source is Personnel) {
      return PersonnelStatus.Retired != source.status;
    } else if (source is Tracking) {
      return TrackingStatus.closed != source.status;
    }
    throw ArgumentError(
      "Aggregate ${source.runtimeType} not supported as tracking Source",
    );
  }

  /// Check if [source] is supported.
  ///
  /// Supported types are:
  /// * [Device]
  /// * [Unit]
  /// * [Personnel]
  /// * [Tracking] (only if [trackable] is supported and not [Tracking])
  static bool isSourceSupported(
    Aggregate source, {
    Trackable trackable,
  }) {
    final type = source.runtimeType;
    switch (type) {
      case Device:
      case Unit:
      case Personnel:
      case Tracking:
        return !(trackable is Tracking) &&
            isSourceSupported(
              trackable,
            );
    }
    return false;
  }

  /// Create tracking from given [trackable] and [sources]
  static Tracking create(
    Trackable trackable, {
    Position position,
    Iterable<Source> sources = const [],
    bool calculate = true,
  }) {
    final tuuid = assertRef(trackable);
    final tracks = _concatAll(sources, []);
    final tracking = Tracking(
      uuid: tuuid,
      position: position,
      sources: tracks.map((t) => t.source).toList(),
      tracks: tracks,
      status: sources.isEmpty ? TrackingStatus.created : TrackingStatus.tracking,
    );
    return calculate ? TrackingUtils.calculate(tracking) : tracking;
  }

  /// Attach [sources] to tracks.
  ///
  /// Source already attached are discarded
  static Tracking attachAll(
    Tracking tracking,
    Iterable<Source> sources, {
    Position position,
    bool calculate = true,
  }) {
    final tracks = _attachAll(tracking.tracks, sources);
    final attached = _toAttaced(tracks);
    final next = tracking.cloneWith(
      position: position,
      tracks: tracks,
      sources: attached,
      status: _derive(
        tracking.status,
        attached.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<Source> _toAttaced(List<Track> tracks) {
    return tracks.where((track) => TrackStatus.attached == track.status).map((track) => track.source).toList();
  }

  /// Replace [sources] with given [sources]
  static Tracking replaceAll(
    Tracking tracking,
    Iterable<Source> sources, {
    Position position,
    bool calculate = true,
  }) {
    final suuids = sources.map((s) => s.uuid);
    var tracks = _detachAll(
      tracking.tracks,
      // Detach tracks not in replaced
      tracking.sources.where((s) => !suuids.contains(s.uuid)).map((s) => s.uuid),
    );

    // Append to existing and create new tracks
    final attached = _attachAll(tracks, sources);
    final replaced = _toReplaced(attached, suuids);
    final next = tracking.cloneWith(
      position: position,
      tracks: attached,
      sources: replaced,
      status: _derive(
        tracking.status,
        replaced.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<Source> _toReplaced(List<Track> attached, Iterable<String> suuids) {
    return attached
        // limit sources to suuids
        .where((t) => suuids.contains(t.source.uuid))
        .map((track) => track.source)
        .toList();
  }

  static List<Track> _attachAll(
    Iterable<Track> tracks,
    Iterable<Source> sources,
  ) {
    final attached = _concatAll(sources, tracks);
    final suuids = sources.map((source) => source.uuid).toList();
    final unchanged = tracks.toList()
      ..removeWhere(
        (track) => suuids.contains(track.source.uuid),
      );
    return unchanged..addAll(attached);
  }

  // Handles duplicate sources by
  // concatenation of unique positions
  // into same track
  static List<Track> _concatAll(Iterable<Source> sources, Iterable<Track> tracks) {
    final attached = <String, Track>{};
    sources.forEach((source) {
      final position = toPosition(source);
      if (position != null) {
        attached.update(
          source.uuid,
          // Only append position if unique
          (track) => track.positions.contains(position)
              ? track
              : track.cloneWith(
                  positions: [...track.positions, position],
                ),
          ifAbsent: () => _attach(tracks, source),
        );
      } else {
        // Replace existing with new
        attached[source.uuid] = _attach(tracks, source);
      }
    });
    return attached.values.toList();
  }

  static Track _attach(Iterable<Track> tracks, Source source) {
    final existing = find(tracks, source.uuid);
    final position = toPosition(source);
    final track = existing == null
        ? _newTrack(
            source,
            position,
          )
        : _cloneTrack(
            existing,
            position,
          );
    return track;
  }

  static Track _cloneTrack(Track existing, Position position) {
    return existing.cloneWith(
      status: TrackStatus.attached,
      positions: List.from(existing.positions)
        ..addAll(
          position == null ? [] : [position],
        ),
    );
  }

  static Track _newTrack(Source source, Position position) {
    return Track(
      id: source.uuid,
      positions: position == null ? [] : [position],
      source: Source.fromJson(source.toJson()),
      status: TrackStatus.attached,
    );
  }

  /// Detach [tracks] with [Track.source] matching [suuids]
  static Tracking detachAll(
    Tracking tracking,
    Iterable<String> suuids, {
    bool calculate = true,
  }) {
    final sources = List<Source>.from(tracking.sources)
      ..removeWhere(
        (source) => suuids.contains(source.uuid),
      );
    List tracks = _detachAll(
      tracking.tracks,
      suuids,
    );
    final next = tracking.cloneWith(
      sources: sources,
      tracks: tracks,
      status: _derive(
        tracking.status,
        sources.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<Track> _detachAll(List<Track> tracks, Iterable<String> suuids) {
    final found = findAll(tracks, suuids);
    final next = List<Track>.from(tracks)
      ..removeWhere(
        (track) => suuids.contains(track.source.uuid),
      )
      ..addAll(
        found.map(
          (track) => track.cloneWith(status: TrackStatus.detached),
        ),
      );
    return next;
  }

  /// Delete [tracks] with [Track.source] matching [suuids]
  static Tracking deleteAll(
    Tracking tracking,
    Iterable<String> suuids, {
    bool calculate = true,
  }) {
    final sources = List<Source>.from(tracking.sources)
      ..removeWhere(
        (source) => suuids.contains(source.uuid),
      );
    List tracks = _deleteAll(
      tracking.tracks,
      suuids,
    );
    final next = tracking.cloneWith(
      sources: sources,
      tracks: tracks,
      status: _derive(
        tracking.status,
        sources.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<Track> _deleteAll(List<Track> tracks, Iterable<String> suuids) {
    return tracks.toList()
      ..removeWhere(
        (track) => suuids.contains(track.source.uuid),
      );
  }

  static Tracking toggle(Tracking tracking, bool closed) {
    return closed ? close(tracking) : reopen(tracking);
  }

  static Tracking close(Tracking tracking) {
    return tracking.cloneWith(
      status: TrackingStatus.closed,
      sources: [],
      tracks: tracking.tracks
          .map((track) => track.cloneWith(
                status: TrackStatus.detached,
              ))
          .toList(),
    );
  }

  static Tracking reopen(Tracking tracking) {
    if (TrackingStatus.closed == tracking.status) {
      final sources = tracking.tracks.map((track) => track.source);
      final tracks = tracking.tracks.map((track) => track.cloneWith(status: TrackStatus.attached));
      return tracking.cloneWith(
        status: _derive(
          TrackingStatus.closed,
          sources.isNotEmpty,
          defaultStatus: TrackingStatus.created,
        ),
        sources: sources.toList(),
        tracks: tracks.toList(),
      );
    }
    return tracking;
  }

  /// Calculate average speed from
  /// [distance] (meter) and [duration]
  /// in unit ['meter/seconds']
  static double speed(double distance, Duration duration) =>
      distance.isNaN == false && duration.inSeconds > 0.0 ? distance / duration.inSeconds : 0.0;

  /// Calculate distance from history
  static double distance(
    List<Position> track, {
    double distance = 0,
    int tail = 2,
  }) {
    distance ??= 0;
    var offset = max(0, track.length - tail);
    var i = offset + 1;
    track?.skip(offset)?.forEach((p) {
      distance += i < track.length
          ? ProjMath.eucledianDistance(
              p.lat,
              p.lon,
              track[i]?.lat ?? p.lat,
              track[i]?.lon ?? p.lon,
            )
          : 0.0;
      i++;
    });
    return distance;
  }

  /// Calculate effort from history
  static Duration effort(List<Position> track) => track?.isNotEmpty == true
      ? track.last.timestamp.difference(
          track.first.timestamp,
        )
      : Duration.zero;

  /// Calculate geometric mean of last position in all
  /// tracks, total distance and effort and average speed.
  ///
  /// If [position] is given with [Position.source] equal to
  /// [PositionSource.manual], a geometric average center of
  /// the last position in each track will not be calculated.
  /// Instead, the manual position is added to history before
  /// distance, effort and speed is calculated.
  ///
  /// The calculation is only performed if [Tracking.status] is
  /// [TrackingStatus.tracking]. For any other [TrackingStatus.values]
  /// the manual [position] will not be added to history.
  ///
  /// [Tracking] instance will always contain given [position]
  /// regardless of which [Tracking.status] given [tracking] has.
  ///
  static Tracking calculate(
    Tracking tracking, {
    Position position,
    TrackingStatus status,
  }) {
    final isManual = PositionSource.manual == position?.source;
    // Calculate geometric centre of all last position in all
    // tracks as the arithmetic mean of positions coordinates
    final next = isManual ? position : average(tracking);

    // Only add tracking history if position has changed
    if (tracking.position != next) {
      final history = List<Position>.from(tracking.history ?? [])..add(next);
      final distance = TrackingUtils.distance(
        history,
        distance: tracking.distance ?? 0,
      );
      final effort = TrackingUtils.effort(history);
      return tracking.cloneWith(
        effort: effort,
        position: next,
        history: history,
        distance: distance,
        speed: speed(distance, effort),
        status: _derive(
          status ?? tracking.status,
          tracking.isNotEmpty,
        ),
      );
    }
    return tracking.cloneWith(
      position: position,
      distance: tracking.distance ?? 0.0,
      effort: tracking.effort ?? Duration.zero,
      speed: tracking.speed ?? 0.0,
      history: tracking.history ?? [],
      status: _derive(
        status ?? tracking.status,
        tracking.isNotEmpty,
      ),
    );
  }

  /// Calculate tracking position as geometric
  /// average of last position in each track
  static Position average(Tracking tracking) {
    final current = tracking.position;
    final sources = tracking.sources;

    // Calculate geometric centre of all
    // source tracks as the arithmetic mean
    // of the input coordinates
    if (sources.isEmpty) {
      return current;
    } else if (sources.length == 1) {
      final track = find(tracking.tracks, sources.first.uuid);
      return _last(track, current);
    }
    final tracks = tracking.tracks;
    // Aggregate lat, lon, acc and latest timestamp in tracks
    var sum = tracks.fold<List<num>>(
      [0.0, 0.0, 0.0, 0.0],
      (sum, track) => track.positions.isEmpty
          ? sum
          : [
              track.positions.last.lat + sum[0],
              track.positions.last.lon + sum[1],
              (track.positions.last.acc ?? 0.0) + sum[2],
              max(
                sum[3],
                track.positions.last.timestamp.millisecondsSinceEpoch,
              ),
            ],
    );
    final count = tracks.length;
    return Position(
      geometry: Point.fromCoords(
        lat: sum[0] / count,
        lon: sum[1] / count,
      ),
      properties: PositionProperties(
        acc: sum[2] / count,
        source: PositionSource.aggregate,
        timestamp: DateTime.fromMillisecondsSinceEpoch(sum[3].toInt()),
      ),
    );
  }

  static Position _last(Track track, Position current) =>
      track?.positions?.isNotEmpty == true ? track.positions.last : current;

  /// Get list of [Point] from given [track]
  static List<Point> toPoints(Track track) =>
      track == null ? [] : track.positions?.map((p) => p.geometry)?.toList() ?? [];

  /// Find track for given [Source] with [suuid]
  static Track find(Iterable<Track> tracks, String suuid) => tracks.firstWhere(
        (track) => track.source.uuid == suuid,
        orElse: () => null,
      );

  /// Find track for given [Source] with [suuid]
  static List<Track> findAll(Iterable<Track> tracks, Iterable<String> suuids) => tracks
      .where((track) => suuids.contains(
            track.source.uuid,
          ))
      .toList();

  static TrackingStatus _derive(
    TrackingStatus current,
    bool isNotEmpty, {
    TrackingStatus defaultStatus,
  }) {
    final next = [TrackingStatus.created].contains(current)
        ? (isNotEmpty ? TrackingStatus.tracking : TrackingStatus.created)
        : (isNotEmpty
            ? TrackingStatus.tracking
            : ([TrackingStatus.closed].contains(current) ? (defaultStatus ?? current) : TrackingStatus.paused));
    return next;
  }

  /// Test if tracking [t1] and [t2] has same state
  static bool same(Tracking t1, Tracking t2) {
    if (!identical(t1, t2)) {
      return listEquals(
        [t1.position, t2.distance, t2.effort, t2.speed],
        [t2.position, t2.distance, t2.effort, t2.speed],
      );
    }
    return true;
  }
}

/// A convenience class for implementing a [Trackable] with [position]
///
/// Should be together with [TrackingUtils.replace]
class PositionableSource<T extends Aggregate> extends Source implements Positionable<Map<String, dynamic>> {
  PositionableSource({
    @required T aggregate,
    @required this.position,
  }) : super(
          uuid: aggregate.uuid,
          type: Source.toSourceType<T>(),
        );

  /// Create positionable source
  static PositionableSource from<T extends Aggregate>(
    T aggregate, {
    Position position,
    bool exists = true,
  }) =>
      PositionableSource<T>(
        aggregate: aggregate,
        position: position ?? TrackingUtils.toPosition(aggregate),
      );

  @override
  final Position position;
}
