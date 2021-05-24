import 'dart:async';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';

abstract class TrackingRepository extends StatefulRepository<String, Tracking, TrackingService> {
  /// Get [Operation.uuid]
  String get ouuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady;

  /// Get [Tracking.uuid] from [value]
  @override
  String toKey(Tracking value);

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
  Iterable<Tracking> findTrackingFrom(
    String suuid, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  });

  /// Load all [Tracking] objects in given [Organisation.uuid]
  Future<List<Tracking>> load(
    String ouuid, {
    Completer<Iterable<Tracking>> onRemote,
  });

  /// Fetch positions for given
  /// [Tracking].
  ///
  /// If [TrackingSource]s are
  /// given, positions for only
  /// those are fetched.
  ///
  /// Returns a [PositionList] if given
  /// [Tracking] exists locally and
  /// tracks given [TrackingSource],
  /// [null] otherwise.
  Future<PositionList> fetchPositionLists(
    String tuuid, {
    List<String> suuids = const [],
    Completer<Iterable<Tracking>> onRemote,
    List<String> options = const ['truncate:-20:m'],
  });
}

class TrackingServiceException extends ServiceException {
  TrackingServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(
          error,
          response: response,
          stackTrace: stackTrace,
        );
}

class TrackingSourceAlreadyTrackedException extends RepositoryIllegalStateValueException {
  final List<String> duplicates;
  TrackingSourceAlreadyTrackedException(
    TrackingRepository repo,
    StorageState state,
    this.duplicates,
  ) : super(repo, state, "Sources already actively tracked: $duplicates");
}
