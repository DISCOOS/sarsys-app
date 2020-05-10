import 'dart:io';

import 'package:SarSys/models/core.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';

class TrackingRepository extends ConnectionAwareRepository<String, Tracking> {
  TrackingRepository(
    this.service, {
    @required ConnectivityService connectivity,
    int compactWhen = 10,
  }) : super(
          connectivity: connectivity,
          compactWhen: compactWhen,
        );

  /// [TrackingService] service
  final TrackingService service;

  /// Get [Incident.uuid]
  String get iuuid => _iuuid;
  String _iuuid;

  /// Map for efficient tracking lookup from source
  final _sources = <String, Set<String>>{};

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _iuuid != null;

  /// Get [Tracking.uuid] from [state]
  @override
  String toKey(StorageState<Tracking> state) {
    return state.value.uuid;
  }

  /// Ensure that box for given [Incident.uuid] is open
  Future<void> _ensure(String iuuid) async {
    if (isEmptyOrNull(iuuid)) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    if (_iuuid != iuuid) {
      await prepare(
        force: true,
        postfix: iuuid,
      );
      _iuuid = iuuid;
    }
  }

  /// Test if source [suuid] is being tracked
  bool has(
    String suuid, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      find(suuid) != null;

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
  Iterable<Tracking> find(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      _sources.containsKey(suuid)
          ? _sources[suuid]
              .map(get)
              .where(
                (tracking) => !exclude.contains(tracking.status),
              )
              .toList()
          : [];

  /// GET ../units
  Future<List<Tracking>> load(String iuuid) async {
    await _ensure(iuuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(iuuid);
        if (response.is200) {
          await clear();
          await Future.wait(response.body.map(
            (unit) => commit(
              StorageState.created(
                unit,
                remote: true,
              ),
            ),
          ));
          return response.body;
        }
        throw TrackingServiceException(
          'Failed to fetch personnel for incident $iuuid',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  /// Create [Tracking]
  Future<Tracking> create(String iuuid, Tracking tracking) async {
    await _ensure(iuuid);
    return apply(
      StorageState.created(tracking),
    );
  }

  /// Update [Tracking]
  Future<Tracking> update(Tracking unit) async {
    checkState();
    return apply(
      StorageState.updated(unit),
    );
  }

  /// Patch [Tracking]
  Future<Tracking> patch(Tracking tracking) async {
    checkState();
    final old = this[tracking.uuid];
    final newJson = JsonUtils.patch(old, tracking);
    return update(
      Tracking.fromJson(newJson..addAll({'uuid': tracking.uuid})),
    );
  }

  /// Delete [Tracking] with given [uuid]
  Future<Tracking> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// Unload all devices for given [iuuid]
  Future<List<Tracking>> unload() async {
    final devices = await clear();
    _iuuid = null;
    return devices;
  }

  /// Commit [state] to repository
  @override
  Future<bool> commit(StorageState<Tracking> state) async {
    final tuuid = state.value.uuid;
    final exists = await super.commit(state);
    if (exists) {
      _addToSourceIndex(state.value, tuuid);
    } else {
      _removeFromSourceIndex(state.value, tuuid);
    }
    return exists;
  }

  void _addToSourceIndex(Tracking tracking, String tuuid) {
    tracking.sources.forEach(
      (source) {
        _sources.update(
          source.uuid,
          (tuuids) => tuuids..add(tuuid),
          ifAbsent: () => {tuuid},
        );
        return;
      },
    );
  }

  void _removeFromSourceIndex(Tracking tracking, String tuuid) {
    final empty = [];
    tracking.sources.forEach(
      (source) {
        final tuuids = _sources.update(
          source.uuid,
          (tuuids) => tuuids..remove(tuuid),
          ifAbsent: () => {},
        );
        if (tuuids.isEmpty) {
          empty.add(source.uuid);
        }
      },
    );
    empty.forEach((suuid) => _sources.remove(suuid));
  }

  /// Clear all states from local storage
  @override
  Future<Iterable<Tracking>> clear({bool compact = true}) async {
    _sources.clear();
    return super.clear(compact: compact);
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
        (source) => find(source.uuid).any((tracking) => tracking.uuid != state.value.uuid),
      )
      .map((source) => source.uuid)
      .toList();

  @override
  Future<Tracking> onCreate(StorageState<Tracking> state) async {
    var response = await service.create(_iuuid, state.value);
    if (response.is200) {
      return response.body;
    }
    throw TrackingServiceException(
      'Failed to create Tracking ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

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
    var response = await service.delete(state.value);
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

class TrackingSourceAlreadyTrackedException extends RepositoryIllegalStateValueException {
  final List<String> duplicates;
  TrackingSourceAlreadyTrackedException(
    StorageState state,
    this.duplicates,
  ) : super(state, "Sources already actively tracked: $duplicates");
}
