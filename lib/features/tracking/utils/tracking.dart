

import 'dart:math';

import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_track_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Methods for idempotent [Tracking] operations
///
/// Handles round-trip updates from server by
/// not adding same [TrackingSource], [TrackingTrack] or
/// [Position] twice.
class TrackingUtils {
  /// Create tracking reference
  static AggregateRef<Tracking> newRef({String? tuuid}) => AggregateRef.fromType<Tracking>(
        tuuid ?? Uuid().v4(),
      );

  /// Ensure tracking reference
  static AggregateRef<Tracking>? ensureRef<T extends Trackable?>(T trackable, {String? tuuid}) =>
      trackable?.tracking?.uuid == null
          // Create new ref
          ? newRef(tuuid: tuuid)
          // Use old ref
          : trackable!.tracking;

  /// Asserts if [trackable] reference is valid.
  ///
  /// [Trackable]s should contain a tracking reference when
  /// they are created. [TrackingBloc] will use this
  /// reference to create a [Tracking] instance which the
  /// backend will create apriori using the same uuid.
  /// This allows for offline creation of tracking objects
  /// in apps resulting in a better user experience
  static String assertRef<T extends Trackable?>(T trackable) {
    final tuuid = trackable!.tracking?.uuid;
    if (tuuid == null) {
      throw ArgumentError(
        "${trackable?.tracking?.type ?? typeOf<T>()} is not configured for tracking: AggregateRef is null",
      );
    }
    return tuuid;
  }

  /// Map collection of [aggregates] to list of [TrackingSource]s
  ///
  /// The position of [Trackable] aggregates are looked
  /// up in [repo]. This position will be used as
  /// initial position in any [TrackingTrack]s attached to
  /// [Tracking] by [TrackingUtils.create] or
  /// [TrackingUtils.attach].
  ///
  /// This method includes only [Aggregate] that are
  /// active if [activeOnly] is true (default).
  ///
  static List<PositionableSource<Aggregate>> toSources<T extends Aggregate>(
    Iterable<T>? aggregates,
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

  static Position? _toPosition(aggregate, TrackingRepository repo) {
    return aggregate is Trackable && repo.containsKey(aggregate.tracking.uuid)
        ? repo[aggregate.tracking.uuid!]!.position
        : toPosition(
            aggregate,
          );
  }

  /// Gets position from aggregate if it is [Positionable]
  static Position? toPosition<T>(T aggregate) => aggregate is Positionable ? aggregate.position : null;

  /// Check if source is active.
  ///
  /// If [source] is not a supported
  /// type an [ArgumentError] is thrown
  static bool isSourceActive(Aggregate? source) {
    if (source is Device) {
      return DeviceStatus.available == source.status;
    } else if (source is Unit) {
      return UnitStatus.retired != source.status;
    } else if (source is Personnel) {
      return PersonnelStatus.retired != source.status;
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
    Aggregate? source, {
    Trackable? trackable,
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
    Trackable? trackable, {
    Position? position,
    Iterable<TrackingSource> sources = const [],
    bool calculate = true,
  }) {
    final tuuid = assertRef(trackable);
    final tracks = _concatAll(sources, []);
    final tracking = TrackingModel(
      uuid: tuuid,
      position: position,
      tracks: tracks.cast<TrackingTrackModel>(),
      sources: tracks.map((t) => t.source).cast<TrackingSourceModel>().toList(),
      status: sources.isEmpty ? TrackingStatus.ready : TrackingStatus.tracking,
    );
    return calculate ? TrackingUtils.calculate(tracking) : tracking;
  }

  /// Attach [sources] to tracks.
  ///
  /// Source already attached are discarded
  static Tracking attachAll(
    Tracking tracking,
    Iterable<TrackingSource> sources, {
    Position? position,
    bool calculate = true,
  }) {
    final tracks = _attachAll(tracking.tracks.cast<TrackingTrackModel>(), sources);
    final attached = _toAttached(tracks);
    final next = tracking.copyWith(
      position: position,
      tracks: tracks,
      sources: attached,
      status: _inferStatus(
        tracking.status,
        attached.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<TrackingSourceModel> _toAttached(List<TrackingTrack> tracks) {
    return tracks
        .where((track) => TrackStatus.attached == track.status)
        .map((track) => track.source)
        .cast<TrackingSourceModel>()
        .toList();
  }

  /// Replace [sources] with given [sources]
  static Tracking replaceAll(
    Tracking tracking,
    Iterable<TrackingSource> sources, {
    Position? position,
    bool calculate = true,
  }) {
    final suuids = sources.map((s) => s.uuid);
    var tracks = _detachAll(
      tracking.tracks as List<TrackingTrackModel>,
      // Detach tracks not in replaced
      tracking.sources.where((s) => !suuids.contains(s.uuid)).map((s) => s.uuid),
    );

    // Append to existing and create new tracks
    final attached = _attachAll(tracks.cast<TrackingTrackModel>(), sources);
    final replaced = _toReplaced(attached, suuids);
    final next = tracking.copyWith(
      position: position,
      tracks: attached,
      sources: replaced,
      status: _inferStatus(
        tracking.status,
        replaced.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<TrackingSourceModel> _toReplaced(List<TrackingTrack> attached, Iterable<String?> suuids) {
    return attached
        // limit sources to suuids
        .where((t) => suuids.contains(t.source!.uuid))
        .map((track) => track.source)
        .cast<TrackingSourceModel>()
        .toList();
  }

  static List<TrackingTrackModel> _attachAll(
    Iterable<TrackingTrack> tracks,
    Iterable<TrackingSource> sources,
  ) {
    final attached = _concatAll(sources, tracks as Iterable<TrackingTrackModel>);
    final suuids = sources.map((source) => source.uuid).toList();
    final List<TrackingTrack> unchanged = tracks.toList()
      ..removeWhere(
        (track) => suuids.contains(track.source!.uuid),
      );
    return unchanged as List<TrackingTrackModel>
      ..addAll(attached.cast<TrackingTrackModel>())
      ..cast<TrackingTrackModel>();
  }

  // Handles duplicate sources by
  // concatenation of unique positions
  // into same track
  static List<TrackingTrackModel> _concatAll(Iterable<TrackingSource> sources, Iterable<TrackingTrackModel> tracks) {
    final attached = <String?, TrackingTrackModel>{};
    sources.forEach((source) {
      final position = toPosition(source);
      if (position != null) {
        attached.update(
          source.uuid,
          // Only append position if unique
          (track) => addUnique(track, position) as TrackingTrackModel,
          ifAbsent: () => _attach(tracks, source) as TrackingTrackModel,
        );
      } else {
        // Replace existing with new
        attached[source.uuid] = _attach(tracks, source) as TrackingTrackModel;
      }
    });
    return attached.values.toList();
  }

  static TrackingTrack addUnique(TrackingTrackModel track, Position? position) {
    final positions = _addUnique(track.positions!, position);
    return track.cloneWith(
      positions: positions as List<Position?>?,
    );
  }

  static Iterable<Position?> _addUnique(List<Position?> positions, Position? position) {
    final found = positions.firstWhere((p) => p!.geometry == position!.geometry, orElse: () => null);
    if (found != null) {
      final idx = positions.indexOf(found);
      final replaced = positions.toList()..replaceRange(idx, idx + 1, [position]);
      return replaced;
    }
    return [...positions, position];
  }

  static TrackingTrack _attach(Iterable<TrackingTrackModel> tracks, TrackingSource source) {
    final existing = find(tracks, source.uuid);
    final position = toPosition(source);
    final track = existing == null
        ? _newTrack(
            source,
            position,
          )
        : existing.cloneWith(
            status: TrackStatus.attached,
            positions: _addUnique(existing.positions!, position) as List<Position?>?,
          );
    return track;
  }

  static TrackingTrack _newTrack(TrackingSource source, Position? position) {
    final positions = position == null ? <Position>[] : <Position>[position];
    final track = TrackingTrackModel(
      id: source.uuid,
      positions: positions,
      status: TrackStatus.attached,
      source: TrackingSourceModel.fromJson(source.toJson()),
    );
    return track;
  }

  /// Detach [tracks] with [TrackingTrack.source] matching [suuids]
  static Tracking detachAll(
    Tracking tracking,
    Iterable<String?> suuids, {
    bool calculate = true,
  }) {
    final sources = List<TrackingSourceModel>.from(tracking.sources)
      ..removeWhere(
        (source) => suuids.contains(source.uuid),
      );
    List tracks = _detachAll(
      tracking.tracks as List<TrackingTrackModel>,
      suuids,
    );
    final next = tracking.copyWith(
      sources: sources,
      tracks: tracks as List<TrackingTrack>?,
      status: _inferStatus(
        tracking.status,
        sources.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<TrackingTrackModel> _detachAll(List<TrackingTrackModel> tracks, Iterable<String?> suuids) {
    final found = findAll(tracks, suuids);
    final next = List<TrackingTrackModel>.from(tracks)
      ..removeWhere(
        (track) => suuids.contains(track.source!.uuid),
      )
      ..addAll(
        found.map(
          (track) => track.cloneWith(status: TrackStatus.detached) as TrackingTrackModel,
        ),
      );
    return next;
  }

  /// Delete [tracks] with [TrackingTrack.source] matching [suuids]
  static Tracking deleteAll(
    Tracking tracking,
    Iterable<String?> suuids, {
    bool calculate = true,
  }) {
    final sources = List<TrackingSourceModel>.from(tracking.sources)
      ..removeWhere(
        (source) => suuids.contains(source.uuid),
      );
    List tracks = _deleteAll(
      tracking.tracks as List<TrackingTrackModel>,
      suuids,
    );
    final next = tracking.copyWith(
      sources: sources,
      tracks: tracks as List<TrackingTrack>?,
      status: _inferStatus(
        tracking.status,
        sources.isNotEmpty,
      ),
    );
    return calculate ? TrackingUtils.calculate(next) : next;
  }

  static List<TrackingTrackModel> _deleteAll(List<TrackingTrackModel> tracks, Iterable<String?> suuids) {
    return tracks.toList()
      ..removeWhere(
        (track) => suuids.contains(track.source!.uuid),
      );
  }

  static Tracking toggle(Tracking tracking, bool closed) {
    return closed ? close(tracking) : reopen(tracking);
  }

  static Tracking close(Tracking tracking) {
    return tracking.copyWith(
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
      return tracking.copyWith(
        status: _inferStatus(
          TrackingStatus.closed,
          sources.isNotEmpty,
          defaultStatus: TrackingStatus.ready,
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
  static double speed(double distance, Duration? duration) =>
      distance.isNaN == false && duration!.inSeconds > 0.0 ? distance / duration.inSeconds : 0.0;

  /// Calculate distance from history
  static double? distance(
    List<Position?> track, {
    double distance = 0,
    int tail = 2,
  }) {
    distance ??= 0;
    var offset = max(0, track.length - tail);
    var i = offset + 1;
    track?.skip(offset)?.where((p) => p!.isNotEmpty)?.forEach((p) {
      distance += i < track.length
          ? ProjMath.eucledianDistance(
              p!.lat!,
              p.lon!,
              track[i]?.lat ?? p.lat!,
              track[i]?.lon ?? p.lon!,
            )
          : 0.0;
      i++;
    });
    return distance;
  }

  /// Calculate effort from history
  static Duration effort(List<Position?> track) => track?.isNotEmpty == true
      ? track.last!.timestamp!.difference(
          track.first!.timestamp!,
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
    Position? position,
    TrackingStatus? status,
  }) {
    final isManual = PositionSource.manual == position?.source;
    // Calculate geometric centre of all last position in all
    // tracks as the arithmetic mean of positions coordinates
    final next = isManual ? position : average(tracking);

    // Only add tracking history if position has changed
    if (tracking.position != next && next!.isNotEmpty) {
      final history = List<Position?>.from(tracking.history ?? [])..add(next);
      final distance = TrackingUtils.distance(
        history,
        distance: tracking.distance ?? 0,
      )!;
      final effort = TrackingUtils.effort(history);
      return tracking.copyWith(
        effort: effort,
        position: next,
        history: history,
        distance: distance,
        speed: speed(distance, effort),
        status: _inferStatus(
          status ?? tracking.status,
          tracking.isNotEmpty,
        ),
      );
    }
    return tracking.copyWith(
      position: position,
      distance: tracking.distance ?? 0.0,
      effort: tracking.effort ?? Duration.zero,
      speed: tracking.speed ?? 0.0,
      history: tracking.history ?? [],
      status: _inferStatus(
        status ?? tracking.status,
        tracking.isNotEmpty,
      ),
    );
  }

  /// Calculate tracking position as geometric
  /// average of last position in each track
  static Position? average(Tracking tracking) {
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
    final sum = tracks
        .where((t) => t.positions?.isNotEmpty == true && t.positions!.last != null)
        .map((t) => t.positions!.last)
        .fold<List<num>>(
      [0.0, 0.0, 0.0, 0.0],
      (sum, p) => [
        p!.lat! + sum[0],
        p.lon! + sum[1],
        (p.acc ?? 0.0) + sum[2],
        max(sum[3], p.timestamp!.millisecondsSinceEpoch),
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

  static Position? _last(TrackingTrack? track, Position? current) =>
      track?.positions?.isNotEmpty == true ? track!.positions!.last : current;

  /// Get list of [Point] from given [track]
  static List<Point?> toPoints(TrackingTrack track) =>
      track == null ? [] : track.positions?.map((p) => p!.geometry)?.toList() ?? [];

  /// Find track for given [TrackingSource] with [suuid]
  static TrackingTrack? find(Iterable<TrackingTrack> tracks, String? suuid) => tracks.firstWhereOrNull(
        (track) => track.source!.uuid == suuid,
      );

  /// Find track for given [TrackingSource] with [suuid]
  static List<TrackingTrack> findAll(Iterable<TrackingTrack> tracks, Iterable<String?> suuids) => tracks
      .where((track) => suuids.contains(
            track.source!.uuid,
          ))
      .toList();

  static TrackingStatus? _inferStatus(
    TrackingStatus? current,
    bool isNotEmpty, {
    TrackingStatus? defaultStatus,
  }) {
    final next = [TrackingStatus.ready].contains(current)
        ? (isNotEmpty ? TrackingStatus.tracking : TrackingStatus.ready)
        : (isNotEmpty
            ? ([TrackingStatus.paused].contains(current) ? (defaultStatus ?? current) : TrackingStatus.tracking)
            : ([TrackingStatus.closed].contains(current) ? (defaultStatus ?? current) : TrackingStatus.ready));
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
class PositionableSource<T extends Aggregate> extends TrackingSourceModel
    implements Positionable<Map<String, dynamic>> {
  PositionableSource({
    required T aggregate,
    required this.position,
  }) : super(
          uuid: aggregate!.uuid,
          type: TrackingSource.toSourceType<T>(),
        );

  /// Should probably add some properties here

  /// Create positionable source
  static PositionableSource from<T extends Aggregate>(
    T aggregate, {
    Position? position,
    bool exists = true,
  }) =>
      PositionableSource<T>(
        aggregate: aggregate,
        position: position ?? TrackingUtils.toPosition(aggregate),
      );

  @override
  final Position? position;
}
