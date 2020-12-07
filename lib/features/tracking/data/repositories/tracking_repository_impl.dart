import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';
import 'package:SarSys/features/tracking/domain/repositories/position_list_repository.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';

class TrackingRepositoryImpl extends StatefulRepository<String, Tracking, TrackingService>
    implements TrackingRepository {
  TrackingRepositoryImpl(
    TrackingService service, {
    @required PositionListRepository tracks,
    @required ConnectivityService connectivity,
  })  : _tracks = tracks,
        super(
          service: service,
          dependencies: [tracks],
          connectivity: connectivity,
        );

  /// Get [Operation.uuid]
  @override
  String get ouuid => _ouuid;
  String _ouuid;

  /// [TrackingTrack] repository
  final PositionListRepository _tracks;

  /// Map for efficient tracking lookup from [Source.uuid]
  final _sources = <String, Set<String>>{};

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _ouuid != null;

  /// Get [Tracking.uuid] from [state]
  @override
  String toKey(StorageState<Tracking> state) {
    return state.value.uuid;
  }

  /// Create [Tracking] from json
  Tracking fromJson(Map<String, dynamic> json) => TrackingModel.fromJson(json);

  /// Open repository for given [Incident.uuid]
  Future<Iterable<Tracking>> open(String ouuid) async {
    if (isEmptyOrNull(ouuid)) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    if (_ouuid != ouuid) {
      await prepare(
        force: true,
        postfix: ouuid,
      );
      _ouuid = ouuid;
    }
    return values;
  }

  /// Test if source [suuid] is being tracked
  ///
  /// If [tracks] is [true] search is performed
  /// on `Tracking.tracks[].source.uuid` instead
  /// of `Tracking.sources[].uuid` (default is false).
  ///
  /// Returns empty list if [source.uuid] is not found
  /// for given set of excluded [TrackingStatus.values].
  ///
  @override
  bool has(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      findTrackingFrom(suuid, tracks: tracks, exclude: exclude).isNotEmpty;

  /// Find tracking from given source [suuid].
  ///
  /// If status [TrackingStatus.closed] is excluded
  /// this method is guaranteed to be empty
  /// or only contain a single [Tracking] as a
  /// result of 'only one active tracking for
  /// each source' rule.
  ///
  /// If [tracks] is [true] search is performed
  /// on `Tracking.tracks[].source.uuid` instead
  /// of `Tracking.sources[].uuid` (default is false).
  ///
  /// Returns empty list if [source.uuid] is not found
  /// for given set of excluded [TrackingStatus.values].
  ///
  @override
  Iterable<Tracking> findTrackingFrom(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    return _sources.containsKey(suuid)
        ? _sources[suuid]
            .map(get)
            // Only if status is not excluded from search
            .where(
              (tracking) => !exclude.contains(tracking.status),
            )
            // Only check if source is attached if tracks are not included in search
            .where(
              (tracking) => tracks || tracking.sources.any((source) => suuid == source.uuid),
            )
            .toList()
        : [];
  }

  /// Load [Tracking] instances for given [ouuid]
  @override
  Future<List<Tracking>> load(
    String ouuid, {
    Completer<Iterable<Tracking>> onRemote,
  }) async {
    await open(ouuid);
    return requestQueue.load(
      () => service.getListFromId(ouuid),
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<PositionList> fetchPositionLists(
    String tuuid, {
    List<String> suuids = const [],
    Completer<Iterable<Tracking>> onRemote,
    List<String> options = const ['truncate:-20:m'],
  }) async {
    if (containsKey(tuuid)) {
      final tracking = get(tuuid);
      final lists = await _tracks.fetch(
        tuuid,
        options: options,
        suuids: suuids.isEmpty ? tracking.sources.map((s) => s.uuid) : suuids,
      );
      return lists.firstOrNull;
    }
    return null;
  }

  /// Unload all [Tracking]s for given [ouuid]
  @override
  Future<List<Tracking>> close() async {
    _ouuid = null;
    return super.close();
  }

  /// Commit [state] to repository
  @override
  bool put(StorageState<Tracking> state) {
    final tuuid = state.value.uuid;
    final exists = super.put(state);
    if (exists) {
      _addToIndex(state.value, tuuid);
    } else {
      _removeFromIndex(state.value, tuuid);
    }
    return exists;
  }

  void _addToIndex(Tracking tracking, String tuuid) {
    // Add to
    tracking.tracks.forEach(
      (track) {
        _sources.update(
          track.source.uuid,
          (tuuids) {
            if (track.status == TrackStatus.attached) {
              tuuids.add(tuuid);
            } else {
              tuuids.remove(tuuid);
            }
            return tuuids;
          },
          ifAbsent: () => {tuuid},
        );
        return;
      },
    );
  }

  void _removeFromIndex(Tracking tracking, String tuuid) {
    final empty = [];
    tracking.tracks.forEach(
      (track) {
        final tuuids = _sources.update(
          track.source.uuid,
          (tuuids) => tuuids..remove(tuuid),
          ifAbsent: () => {},
        );
        if (tuuids.isEmpty) {
          empty.add(track.source.uuid);
        }
      },
    );
    empty.forEach((suuid) => _sources.remove(suuid));
  }

  /// Clear all states from local storage
  @override
  Iterable<Tracking> clear() {
    _sources.clear();
    return super.clear();
  }

  @override
  StorageState<Tracking> validate(StorageState<Tracking> state) {
    // Verify "one active track per source" policy
    if (!(state.isRemote || state.isDeleted)) {
      final duplicates = _duplicates(state);
      if (duplicates.isNotEmpty) {
        throw TrackingSourceAlreadyTrackedException(
          state,
          duplicates,
        );
      }
    }
    return super.validate(state);
  }

  Iterable<String> _duplicates(StorageState<Tracking> state) => state.value.sources
      .where(
        // Search for active trackings not equal to tracking in given state
        (source) => findTrackingFrom(source.uuid).any((tracking) => tracking.uuid != state.value.uuid),
      )
      .map((source) => source.uuid)
      .toList();

  @override
  Future<Iterable<Tracking>> onReset({Iterable<Tracking> previous}) =>
      _ouuid != null ? load(_ouuid) : Future.value(previous);

  /// Tracking are created in the backend,
  /// just return current value
  @override
  Future<Tracking> onCreate(StorageState<Tracking> state) => Future.value(state.value);

  @override
  Future<Tracking> onUpdate(StorageState<Tracking> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    }
    throw TrackingServiceException(
      'Failed to update Tracking ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Tracking> onDelete(StorageState<Tracking> state) => Future.value(state.value);
}
