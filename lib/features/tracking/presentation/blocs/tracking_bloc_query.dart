

import 'dart:collection';

import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:collection/collection.dart' show IterableExtension;

import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';

import 'tracking_bloc.dart';

/// -------------------------------------------------
/// Helper class for querying [Trackable] aggregates
/// -------------------------------------------------
class TrackableQuery<T extends Trackable?> {
  final TrackingBloc bloc;
  final Map<String, T> _data;

  TrackableQuery({
    /// [TrackingBloc] managing tracking objects
    required this.bloc,

    /// Mapping from [Aggregate.uuid] to Aggregate of type [T]
    required Map<String, T> data,
  }) : this._data = UnmodifiableMapView(_toTracked(data as Map<String, Never>, bloc.repo));

  static Map<String, T> _toTracked<String, T extends Trackable?>(Map<String, T> data, TrackingRepository repo) {
    return Map.from(data)..removeWhere((_, trackable) => !repo.containsKey(trackable!.tracking.uuid));
  }

  /// Get map of [Tracking.uuid] to aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping if found.
  ///
  Map<String, T> get map => _data;

  /// Get tracked aggregates of type [T]
  Iterable<T> get trackables => _data.values;

  /// Get [Tracking] instances
  Iterable<Tracking?> get trackings => _data.keys.map((tuuid) => bloc.repo[tuuid]);

  /// Test if given [trackable] is a source in any [Tracking] in this [TrackableQuery]
  bool contains(T trackable) => _data.containsKey(trackable!.uuid);

  /// Get [Tracking] from given [Trackable] of type [T]
  Tracking? elementAt(T trackable) => bloc.repo[trackable!.tracking.uuid!];

  /// Get aggregate of type [T] tracked by given [Tracking.uuid]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping if found.
  ///
  T? trackedBy(String? tuuid) => _data.values.firstWhereOrNull(
        (trackable) => trackable!.tracking.uuid == tuuid,
      );

  /// Find aggregate of type [T] tracking [tracked]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  T find(
    Aggregate? tracked, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    var found;
    // Use direct lookup if trackable
    final tuuid = tracked is Trackable ? tracked.tracking.uuid : null;
    if (tuuid != null) {
      found = trackedBy(tuuid);
    }
    // Search in sources?
    if (found == null) {
      found = where(exclude: exclude).trackables.firstWhereOrNull(
            (trackable) =>
                bloc.repo[trackable!.tracking.uuid!]?.sources.any(
                  (source) => source.uuid == tracked!.uuid,
                ) ??
                false,
          );
    }
    return found;
  }

  /// Get filtered map of [Tracking.uuid] to [Device] or
  /// [Trackable] tracked by aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  TrackableQuery<T> where({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      TrackableQuery(
        bloc: bloc,
        data: Map.fromEntries(
          _data.entries.where(
            (entry) => !exclude.contains(elementAt(entry.value)?.status),
          ) as Iterable<MapEntry<String, Never>>,
        ),
      );

  /// Get map of [Device.uuid] to tracked by aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  Map<String?, T> devices({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String?, T> map = {};
    trackables.forEach((trackable) {
      bloc.devices(trackable!.tracking.uuid).forEach((device) {
        map.update(device.uuid, (set) => trackable, ifAbsent: () => trackable);
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Get map of [Personnel.uuid] to tracking aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  /// Only aggregates of type [Unit] are allowed to track
  /// [Personnel]. The [Tracking] referenced by [Unit] will
  /// append the [Tracking.position] of the [Tracking]
  /// referenced by [Personnel].
  ///
  Map<String?, T> personnels({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String?, T> map = {};
    final personnels = bloc.personnels.where(exclude: exclude);
    // For each Unit
    trackables.forEach((trackable) {
      // Find tracking of unit
      final tracking = elementAt(trackable)!;
      // Collect tracking of personnels
      tracking.sources
          // Only consider personnels that exists
          .where((source) => personnels.map.containsKey(source.uuid))
          // Get personnel from source uuid
          .map((source) => personnels.map[source.uuid])
          // Update mapping between personnel and trackable T
          .forEach(
            (personnel) => map.update(
              personnel!.uuid,
              (set) => trackable,
              ifAbsent: () => trackable,
            ),
          );
    });
    return UnmodifiableMapView(map);
  }
}
