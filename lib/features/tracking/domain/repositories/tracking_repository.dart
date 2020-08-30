import 'dart:async';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';

abstract class TrackingRepository extends ConnectionAwareRepository<String, Tracking, TrackingService> {
  TrackingRepository(
    TrackingService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid]
  String get ouuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady;

  /// Get [Tracking.uuid] from [state]
  @override
  String toKey(StorageState<Tracking> state);

  /// Test if source [suuid] is being tracked
  ///
  /// If [tracks] is [true] search is performed
  /// on `Tracking.tracks[].source.uuid` instead
  /// of `Tracking.sources[].uuid` (default is false).
  ///
  /// Returns empty list if [source.uuid] is not found
  /// for given set of excluded [TrackingStatus.values].
  ///
  bool has(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  });

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
  Iterable<Tracking> findTracingFrom(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  });

  /// GET ../units
  Future<List<Tracking>> load(
    String ouuid, {
    Completer<Iterable<Tracking>> onRemote,
  });
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
