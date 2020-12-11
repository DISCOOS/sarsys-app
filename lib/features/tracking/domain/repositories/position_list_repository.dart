import 'dart:async';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/tracking/data/services/position_list_service.dart';
import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';

abstract class PositionListRepository implements StatefulRepository<String, PositionList, PositionListService> {
  /// Get [PositionList.id] from [value]
  @override
  String toKey(PositionList value);

  /// Find tracks matching given query
  Iterable<PositionList> find({bool where(PositionList list)});

  /// Init from local storage, overwrite states
  /// with given tracks if given. Returns
  /// number of states after initialisation
  Future<int> init({Map<String, List<TrackingTrack>> tracks});

  /// Load positions for given [Tracking] and [TrackingSource] uuids.
  Future<Iterable<PositionList>> fetch(
    String tuuid, {
    bool replace = false,
    Iterable<String> suuids,
    Completer<Iterable<PositionList>> onRemote,
    List<String> options = const ['truncate:-20:m'],
  });
}

class PositionListServiceException extends ServiceException {
  PositionListServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(error, response: response, stackTrace: stackTrace);
}
