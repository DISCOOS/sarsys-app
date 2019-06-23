import 'dart:collection';

import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc extends Bloc<TrackingCommand, TrackingState> {
  final TrackingService service;

  final LinkedHashMap<String, Tracking> _tracks = LinkedHashMap();

  TrackingBloc(this.service);

  @override
  TrackingState get initialState => TracksEmpty();

  /// Check if [tracks] is empty
  bool get isEmpty => tracks.isEmpty;

  /// Get tracks
  Map<String, Tracking> get tracks => UnmodifiableMapView<String, Tracking>(_tracks);

  /// Initialize if empty
  TrackingBloc init(TrackingCallback onInit) {
    if (isEmpty) {
      fetch().then((_) => onInit(() {}));
    }
    return this;
  }

  /// Create given tracking
  TrackingBloc create(Tracking tracking) {
    dispatch(CreateTracking(tracking));
    return this;
  }

  /// Update given tracking
  TrackingBloc update(Tracking tracking) {
    dispatch(UpdateTracking(tracking));
    return this;
  }

  /// Fetch tracks from [service]
  Future<List<Tracking>> fetch() async {
    dispatch(ClearTracks(_tracks.keys.toList()));
    var tracks = await service.fetch();
    dispatch(LoadTracks(tracks));
    return UnmodifiableListView<Tracking>(tracks);
  }

  @override
  Stream<TrackingState> mapEventToState(TrackingCommand command) async* {
    if (command is LoadTracks) {
      List<String> ids = _load(command.data);
      yield TracksLoaded(ids);
    } else if (command is CreateTracking) {
      Tracking data = await _create(command);
      yield TrackingCreated(data);
    } else if (command is UpdateTracking) {
      Tracking data = await _update(command);
      yield TrackingUpdated(data);
    } else if (command is DeleteTracking) {
      Tracking data = await _delete(command);
      yield TrackingDeleted(data);
    } else if (command is ClearTracks) {
      List<Tracking> tracks = _clear(command);
      yield TracksCleared(tracks);
    } else if (command is RaiseTrackingError) {
      yield command.data;
    } else {
      yield TrackingError("Unsupported $command");
    }
  }

  List<String> _load(List<Tracking> tracks) {
    //TODO: Implement call to backend

    _tracks.addEntries(tracks.map(
      (tracking) => MapEntry(tracking.id, tracking),
    ));
    return _tracks.keys.toList();
  }

  Future<Tracking> _create(CreateTracking event) async {
    //TODO: Implement call to backend

    var data = _tracks.putIfAbsent(
      event.data.id,
      () => event.data,
    );
    return Future.value(data);
  }

  Future<Tracking> _update(UpdateTracking event) async {
    //TODO: Implement call to backend

    var data = _tracks.update(
      event.data.id,
      (tracking) => event.data,
      ifAbsent: () => event.data,
    );
    return Future.value(data);
  }

  Future<Tracking> _delete(DeleteTracking event) {
    //TODO: Implement call to backend

    if (_tracks.remove(event.data.id) == null) {
      throw "Failed to delete tracking ${event.data.id}";
    }
    return Future.value(event.data);
  }

  List<Tracking> _clear(ClearTracks command) {
    List<Tracking> cleared = [];
    command.data.forEach((id) => {if (_tracks.containsKey(id)) cleared.add(_tracks.remove(id))});
    return cleared;
  }

  @override
  void onEvent(TrackingCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<TrackingCommand, TrackingState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseTrackingError(TrackingError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<T> extends Equatable {
  final T data;

  TrackingCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadTracks extends TrackingCommand<List<Tracking>> {
  LoadTracks(List<Tracking> data) : super(data);

  @override
  String toString() => 'LoadTracks';
}

class CreateTracking extends TrackingCommand<Tracking> {
  CreateTracking(Tracking data) : super(data);

  @override
  String toString() => 'CreateTracking';
}

class UpdateTracking extends TrackingCommand<Tracking> {
  UpdateTracking(Tracking data) : super(data);

  @override
  String toString() => 'UpdateTracking';
}

class DeleteTracking extends TrackingCommand<Tracking> {
  DeleteTracking(Tracking data) : super(data);

  @override
  String toString() => 'DeleteTracking';
}

class ClearTracks extends TrackingCommand<List<String>> {
  ClearTracks(List<String> data) : super(data);

  @override
  String toString() => 'ClearTracks';
}

class RaiseTrackingError extends TrackingCommand<TrackingError> {
  RaiseTrackingError(data) : super(data);

  @override
  String toString() => 'RaiseTrackingError';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class TrackingState<T> extends Equatable {
  final T data;

  TrackingState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is TracksEmpty;
  isLoaded() => this is TracksLoaded;
  isCreated() => this is TrackingCreated;
  isUpdated() => this is TrackingUpdated;
  isDeleted() => this is TrackingDeleted;
  isCleared() => this is TracksCleared;
  isException() => this is TrackingException;
  isError() => this is TrackingError;
}

class TracksEmpty extends TrackingState<Null> {
  TracksEmpty() : super(null);

  @override
  String toString() => 'TracksEmpty';
}

class TracksLoaded extends TrackingState<List<String>> {
  TracksLoaded(List<String> data) : super(data);

  @override
  String toString() => 'TracksLoaded';
}

class TrackingCreated extends TrackingState<Tracking> {
  TrackingCreated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingCreated';
}

class TrackingUpdated extends TrackingState<Tracking> {
  TrackingUpdated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingUpdated';
}

class TrackingDeleted extends TrackingState<Tracking> {
  TrackingDeleted(Tracking data) : super(data);

  @override
  String toString() => 'TrackingDeleted';
}

class TracksCleared extends TrackingState<List<Tracking>> {
  TracksCleared(List<Tracking> tracks) : super(tracks);

  @override
  String toString() => 'TracksCleared';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class TrackingException extends TrackingState<Object> {
  final StackTrace trace;
  TrackingException(Object error, {this.trace}) : super(error, [trace]);

  @override
  String toString() => 'TrackingException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class TrackingError extends TrackingException {
  final StackTrace trace;
  TrackingError(Object error, {this.trace}) : super(error, trace: trace);

  @override
  String toString() => 'TrackingError {data: $data}';
}
