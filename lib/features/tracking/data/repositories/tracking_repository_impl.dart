import 'dart:io';

import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/domain/entities/Track.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';

class TrackingRepositoryImpl extends ConnectionAwareRepository<String, Tracking, TrackingService>
    implements TrackingRepository {
  TrackingRepositoryImpl(
    TrackingService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid]
  @override
  String get ouuid => _ouuid;
  String _ouuid;

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

  /// Ensure that box for given [Incident.uuid] is open
  Future<void> _ensure(String ouuid) async {
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
      findTracingFrom(suuid, tracks: tracks, exclude: exclude).isNotEmpty;

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
  Iterable<Tracking> findTracingFrom(
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
  Future<List<Tracking>> load(String ouuid) async {
    await _ensure(ouuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetchAll(ouuid);
        if (response.is200) {
          evict(
            retainKeys: response.body.map((tracking) => tracking.uuid),
          );

          response.body.forEach(
            (unit) => put(
              StorageState.created(
                unit,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw TrackingServiceException(
          'Failed to fetch personnel for operation $ouuid',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  /// Create [Tracking] for given [ouuid]
  @override
  Future<Tracking> create(String ouuid, Tracking tracking) async {
    await _ensure(ouuid);
    return apply(
      StorageState.created(tracking),
    );
  }

  /// Update [Tracking]
  @override
  Future<Tracking> update(Tracking unit) async {
    checkState();
    return apply(
      StorageState.updated(unit),
    );
  }

  /// Patch [Tracking]
  @override
  Future<Tracking> patch(Tracking tracking) async {
    checkState();
    final old = this[tracking.uuid];
    final newJson = JsonUtils.patch(old, tracking);
    return update(
      TrackingModel.fromJson(newJson..addAll({'uuid': tracking.uuid})),
    );
  }

  /// Delete [Tracking] with given [uuid]
  @override
  Future<Tracking> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
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
        (source) => findTracingFrom(source.uuid).any((tracking) => tracking.uuid != state.value.uuid),
      )
      .map((source) => source.uuid)
      .toList();

  @override
  Future<Iterable<Tracking>> onReset() => _ouuid != null ? load(_ouuid) : Future.value(values);

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
  Future<Tracking> onDelete(StorageState<Tracking> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    }
    throw TrackingServiceException(
      'Failed to delete Tracking ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class TrackingServiceException implements Exception {
  TrackingServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'TrackingServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
