

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';

/// ---------------------
/// Normal States
/// ---------------------
abstract class TrackingState<T> extends PushableBlocEvent<T> {
  TrackingState(
    Object? data, {
    StackTrace? stackTrace,
    props = const [],
    bool isRemote = false,
  }) : super(
          data as T,
          isRemote: isRemote,
          stackTrace: stackTrace,
        );

  isEmpty() => this is TrackingsEmpty;
  isLoaded() => this is TrackingsLoaded;
  isCreated() => this is TrackingCreated;
  isUpdated() => this is TrackingUpdated;
  isDeleted() => this is TrackingDeleted;
  isUnloaded() => this is TrackingsUnloaded;
  isError() => this is TrackingBlocError;

  bool isStatusChanged() => false;
  bool isLocationChanged() => false;
}

class TrackingsEmpty extends TrackingState<Object> {
  TrackingsEmpty() : super(null);

  @override
  String toString() => '$runtimeType';
}

class TrackingsLoaded extends TrackingState<List<String>> {
  TrackingsLoaded(
    List<String?> data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {trackings: $data, isRemote: $isRemote}';
}

class TrackingCreated extends TrackingState<Tracking> {
  TrackingCreated(
    Tracking? data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {tracking: $data, isRemote: $isRemote}';
}

class TrackingUpdated extends TrackingState<Tracking> {
  TrackingUpdated(
    Tracking? data,
    this.previous, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  final Tracking? previous;

  bool isChanged() => data != previous;
  bool isStatusChanged() => data.status != previous?.status;
  bool isLocationChanged() => data.position != previous?.position;

  @override
  String toString() => '$runtimeType {tracking: $data, isRemote: $isRemote}';
}

class TrackingDeleted extends TrackingState<Tracking> {
  TrackingDeleted(
    Tracking? data, {
    bool isRemote = false,
  }) : super(data, isRemote: isRemote);

  @override
  String toString() => '$runtimeType {tracking: $data, isRemote: $isRemote}';
}

class TrackingsUnloaded extends TrackingState<List<Tracking>> {
  TrackingsUnloaded(List<Tracking?> tracks) : super(tracks);

  @override
  String toString() => '$runtimeType {trackings: $data}';
}

/// ---------------------
/// Error States
/// ---------------------

class TrackingBlocError extends TrackingState<Object> {
  final StackTrace? stackTrace;

  TrackingBlocError(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => '$runtimeType {data: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------
///
class TrackingNotFoundException extends TrackingBlocException {
  TrackingNotFoundException(String tuuid, TrackingState state)
      : super(
          'Tracking $tuuid not found',
          state,
        );
}

class TrackingBlocException implements Exception {
  TrackingBlocException(this.error, this.state, {this.command, this.stackTrace});

  final Object error;
  final Object? command;
  final TrackingState state;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType {'
      'error: $error, '
      'state: ${state.toString().substring(0, 50)}, '
      'command: ${command?.toString().substring(0, 50)}, '
      'stackTrace: $stackTrace'
      '}';
}
