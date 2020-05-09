import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Source.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/repositories/tracking_repository.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc extends Bloc<TrackingCommand, TrackingState> {
  TrackingBloc(
    this.repo, {
    @required this.incidentBloc,
    @required this.deviceBloc,
    @required this.unitBloc,
    @required this.personnelBloc,
  }) {
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    assert(unitBloc != null, "unitBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    assert(deviceBloc != null, "deviceBloc can not be null");
    _subscriptions
      // Handles incident state changes
      ..add(incidentBloc.listen(_handleIncidentEvent))
      // Manages tracking state for units
      ..add(unitBloc.listen(_handleUnitEvent))
      // Manages tracking state for personnel
      ..add(personnelBloc.listen(_handlePersonnelEvent))
      // Manages tracking state for devices
      ..add(deviceBloc.listen(_processDeviceEvent))
      // Process tracking messages
      ..add(service.messages.listen(_handleMessage));
  }

  /// Get [IncidentBloc]
  final IncidentBloc incidentBloc;

  /// Get [UnitBloc]
  final UnitBloc unitBloc;

  /// Get [PersonnelBloc]
  final PersonnelBloc personnelBloc;

  /// Get [DeviceBloc]
  final DeviceBloc deviceBloc;

  /// Get [TrackingRepository]
  final TrackingRepository repo;

  /// Get [TrackingService]
  TrackingService get service => repo.service;

  /// Subscriptions released on [close]
  List<StreamSubscription> _subscriptions = [];

  /// [Incident] that manages given [devices]
  String get iuuid => repo.iuuid;

  /// Check if [Incident.uuid] is not set
  bool get isUnset => repo.iuuid == null;

  /// Check if repository is offline
  bool get isOffline => repo.isOffline;

  @override
  TrackingState get initialState => TrackingsEmpty();

  /// Process [IncidentState] events
  ///
  /// Invokes [load] and [unload] as needed.
  ///
  void _handleIncidentEvent(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty) {
        // Clear out current tracking upon states given below
        if (state.shouldUnload(iuuid)) {
          add(UnloadTrackings(iuuid));
        } else if (state.isSelected()) {
          add(LoadTrackings(state.data.uuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      add(
        RaiseTrackingError(error, stackTrace: stackTrace),
      );
    }
  }

  /// Process [DeviceState] events.
  ///
  /// Updates associated [Tracking] object
  /// apriori to changes made in backend.
  ///
  /// Each change is applied directly to
  /// local state and is idempotent.
  ///
  /// Event [DeviceUpdated] will update track
  /// and aggregate values in [Tracking]
  /// if [Device.position] has changed.
  ///
  /// Event [DeviceDeleted] will update [Tracking]
  /// aggregate values after associated source and
  /// track entries are removed.
  ///
  void _processDeviceEvent(DeviceState state) {
    try {
      if (state.isLocationChanged() || state.isStatusChanged()) {
        final device = state.data as Device;
        final trackings = find(device);
        if (trackings.isNotEmpty) {
          final next = state.isAvailable()
              ? TrackingUtils.attachAll(
                  trackings.first,
                  [PositionableSource.from<Device>(device)],
                )
              : TrackingUtils.detachAll(
                  trackings.first,
                  [device.uuid],
                );
          add(_toInternalChange(next));
        } else if (state.isUnavailable()) {
          // Look for detached device in tracks
          final trackings = find(device, tracks: true);
          if (trackings.isNotEmpty) {
            // Re-attach device
            final next = TrackingUtils.attachAll(
              trackings.first,
              [PositionableSource.from<Device>(device)],
            );
            add(_toInternalChange(next));
          }
        }
      } else if (state.isDeleted()) {
        final device = state.data;
        final trackings = find(device);
        if (trackings.isNotEmpty) {
          final next = TrackingUtils.deleteAll(
            trackings.first,
            [device.uuid],
          );
          add(_toInternalChange(next));
        }
      }
    } on Exception catch (error, stackTrace) {
      add(
        RaiseTrackingError(error, stackTrace: stackTrace),
      );
    }
  }

  /// Process [UnitState] changes.
  ///
  /// Updates associated [Tracking] object
  /// apriori to changes made in backend.
  ///
  /// Each change is applied directly to
  /// local state and is idempotent.
  ///
  /// Event [UnitCreated] will create a
  /// [Tracking] object if [Unit.tracking] is given.
  ///
  /// Event [UnitUpdated] will change
  /// [Tracking] status to [TrackingStatus.closed]
  /// if [Unit.status] has changed to [UnitStatus.Retired],
  /// or change to a status deferred from [Unit.status].
  ///
  /// Event [UnitDeleted] will delete associated [Tracking].
  ///
  void _handleUnitEvent(UnitState state) {
    try {
      if (state.isCreated() && state.isTracked() && !state.isRetired()) {
        final unit = (state as UnitCreated).data;
        final tracking = TrackingUtils.create(
          unit,
          sources: TrackingUtils.toSources(unit.personnels, repo),
        );
        // Backend will perform this apriori
        add(_toInternalCreate(
          tracking,
        ));
      } else if (state.isUpdated() && state.isStatusChanged()) {
        final unit = (state as UnitUpdated).data;
        final tracking = repo[unit.tracking?.uuid];
        if (tracking != null) {
          final next = TrackingUtils.toggle(
            tracking,
            state.isRetired(),
          );
          // TODO: Backend will perform this apriori
          add(_toInternalChange(
            next,
          ));
        } else if (!state.isRetired()) {
          // Backend will perform this apriori
          add(_toInternalCreate(
            tracking,
          ));
        }
      } else if (state.isDeleted()) {
        final unit = (state as UnitDeleted).data;
        final tracking = repo[unit.tracking?.uuid];
        if (tracking != null) {
          // Backend will perform this apriori
          add(_toInternalDelete(
            tracking,
          ));
        }
      }
    } on Exception catch (error, stackTrace) {
      add(
        RaiseTrackingError(error, stackTrace: stackTrace),
      );
    }
  }

  /// Process [PersonnelState] changes.
  ///
  /// Updates associated [Tracking] object
  /// apriori to changes made in backend.
  ///
  /// Each change is applied directly to
  /// local state and is idempotent.
  ///
  /// Event [PersonnelCreated] will create a
  /// [Tracking] object if [Personnel.tracking] is given.
  ///
  /// Event [PersonnelUpdated] will change
  /// [Tracking] status to [TrackingStatus.closed]
  /// if [Personnel.status] has changed to [PersonnelStatus.Retired],
  /// or change to a status deferred from [Personnel.status].
  ///
  /// Event [PersonnelDeleted] will delete associated [Tracking].
  ///
  void _handlePersonnelEvent(PersonnelState state) {
    try {
      if (state.isCreated() && state.isTracked() && !state.isRetired()) {
        final personnel = (state as PersonnelCreated).data;
        final tracking = TrackingUtils.create(personnel);
        // Backend will perform this apriori
        add(_toInternalCreate(
          tracking,
        ));
      } else if (state.isUpdated() && state.isStatusChanged()) {
        final personnel = (state as PersonnelUpdated).data;
        final tracking = repo[personnel.tracking?.uuid];
        if (tracking != null) {
          final next = TrackingUtils.toggle(
            tracking,
            state.isRetired(),
          );
          // Backend will perform this apriori
          add(_toInternalChange(
            next,
          ));
        } else if (!state.isRetired()) {
          // Backend will perform this apriori
          add(_toInternalCreate(
            tracking,
          ));
        }
      } else if (state.isDeleted()) {
        final personnel = (state as PersonnelDeleted).data;
        final tracking = repo[personnel.tracking?.uuid];
        if (tracking != null) {
          // Backend will perform this apriori
          add(_toInternalDelete(
            tracking,
          ));
        }
      }
    } on Exception catch (error, stackTrace) {
      add(
        RaiseTrackingError(error, stackTrace: stackTrace),
      );
    }
  }

  /// Dispatches [TrackingMessage]s from
  /// [TrackingService] as an internal [_HandleMessage]
  /// command processed by method [_process]
  void _handleMessage(TrackingMessage event) {
    if (repo.containsKey(event.uuid)) {
      add(_HandleMessage(
        event,
        internal: false,
      ));
    }
  }

  /// Stream of tracking changes for test
  Stream<Tracking> onChanged(String uuid) => where(
        (state) =>
            (state is TrackingUpdated && state.data.uuid == uuid) ||
            (state is TrackingsLoaded && state.data.contains(uuid)),
      ).map((state) => state is TrackingsLoaded ? repo[uuid] : state.data);

  /// Get all tracking objects
  Map<String, Tracking> get trackings => repo.map;

  /// Get units being tracked
  Entities<Unit> get units => Entities<Unit>(
        bloc: this,
        data: this.unitBloc.units,
        asId: (unit) => unit?.tracking?.uuid,
      );

  /// Get [personnels] being tracked
  Entities<Personnel> get personnels => Entities<Personnel>(
        bloc: this,
        data: this.personnelBloc.personnels,
        asId: (personnel) => personnel?.tracking?.uuid,
      );

  /// Get aggregates being tracked
  Entities<Tracking> get trackables => Entities<Tracking>(
        bloc: this,
        data: Map.fromEntries(
          repo.values.where((tracking) => tracking.sources.isNotEmpty).fold(
            {},
            (map, tracking) => map.toList()
              ..addAll(
                tracking.sources
                    .where((source) => SourceType.trackable == source.type)
                    .map((source) => MapEntry(source.uuid, repo[source.uuid])),
              ),
          ),
        ),
        asId: (aggregate) => aggregate?.uuid,
      );

  /// Test if [device] is being tracked
  bool has(
    Device device, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      repo.has(device.uuid);

  /// Find tracking from given [aggregate].
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
    Aggregate aggregate, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      repo.find(
        aggregate.uuid,
        tracks: tracks,
        exclude: exclude,
      );

  /// Get devices being tracked by given [Tracking.uuid]
  List<Device> devices(
    String tuuid, {
    List<TrackingStatus> exclude = const [TrackingStatus.closed],
  }) =>
      repo.containsKey(tuuid) && !exclude.contains(repo[tuuid].status)
          ? repo[tuuid]
              .sources
              .where((source) => deviceBloc.devices.containsKey(source.uuid))
              .map((source) => deviceBloc.devices[source.uuid])
              .toList()
          : [];

  /// Get tracking for all tracked devices as a map from device id to all [Tracking] instances tracking the device
  Map<String, Set<Tracking>> asDeviceIds({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String, Set<Tracking>> map = {};
    repo.values.where((tracking) => !exclude.contains(tracking.status)).forEach((tracking) {
      devices(tracking.uuid).forEach((device) {
        map.update(device.uuid, (set) => set..add(tracking), ifAbsent: () => {tracking});
      });
    });
    return UnmodifiableMapView(map);
  }

  void _assertState() {
    if (incidentBloc.isUnset) {
      throw TrackingBlocException(
        "No incident selected. Ensure that "
        "'IncidentBloc.select(String uuid)' is called before 'TrackingBloc.load()'",
        state,
      );
    }
  }

  /// Use current iuuid if exists or selected iuuid from IncidentBloc if exists
  String _ensureIuuid() => iuuid ?? incidentBloc.selected?.uuid;

  /// Load [trackings] from [service]
  Future<List<Tracking>> load() async {
    _assertState();
    return _dispatch<List<Tracking>>(
      LoadTrackings(_ensureIuuid()),
    );
  }

  /// Attach [devices] and [personnels] to given [tracking]
  Future<Tracking> attach(
    Tracking tracking, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<Personnel> personnels,
  }) {
    final sources = _toSources(
      devices,
      personnels,
    );
    final next = sources == null
        ? tracking
        : TrackingUtils.attachAll(
            tracking,
            sources,
            calculate: false,
          );
    return update(
      next,
      status: status,
      position: position,
    );
  }

  /// Replace [devices] and [personnels] in given [tracking]
  ///
  /// Only [devices] and [personnels] already attached are replaced.
  Future<Tracking> replace(
    Tracking tracking, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<Personnel> personnels,
  }) {
    final sources = _toSources(
      devices,
      personnels,
    );
    final next = sources == null
        ? tracking
        : TrackingUtils.replaceAll(
            tracking,
            sources,
            calculate: false,
          );
    return update(
      next,
      status: status,
      position: position,
    );
  }

  /// Detach [devices] and [personnel] from given [tracking]
  Future<Tracking> detach(
    Tracking tracking, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<Personnel> personnel,
  }) {
    final sources = _toSources(
      devices,
      personnel,
    );
    final next = sources == null
        ? tracking
        : TrackingUtils.deleteAll(
            tracking,
            sources.map((s) => s.uuid),
            calculate: false,
          );
    return update(
      next,
      status: status,
      position: position,
    );
  }

  /// Update given [tracking]
  Future<Tracking> update(
    Tracking tracking, {
    Position position,
    TrackingStatus status,
  }) {
    return _dispatch(
      UpdateTracking(
        TrackingUtils.calculate(
          tracking,
          status: status,
          position: position?.cloneWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
      ),
    );
  }

  List<PositionableSource<Aggregate>> _toSources(List<Device> devices, List<Personnel> personnel) {
    final replaceDevices = devices != null;
    final replacePersonnel = personnel != null;
    final sources = [
      if (replaceDevices) ...TrackingUtils.toSources(devices, repo),
      if (replacePersonnel) ...TrackingUtils.toSources(personnel, repo),
    ];
    return sources;
  }

  /// Unload [trackings] from local storage
  Future<List<Tracking>> unload() {
    _assertState();
    return _dispatch<List<Tracking>>(
      UnloadTrackings(iuuid),
    );
  }

  /// Create [_HandleMessage] for processing [TrackingMessageType.updated]
  _HandleMessage _toInternalCreate(Tracking tracking) => _HandleMessage(
        TrackingMessage(
          tracking.uuid,
          TrackingMessageType.created,
          tracking.toJson(),
        ),
        internal: true,
      );

  /// Create [_HandleMessage] for processing [TrackingMessageType.updated]
  _HandleMessage _toInternalChange(Tracking tracking) => _HandleMessage(
        TrackingMessage(
          tracking.uuid,
          TrackingMessageType.updated,
          tracking.toJson(),
        ),
        internal: true,
      );

  /// Create [_HandleMessage] for processing [TrackingMessageType.deleted].
  _HandleMessage _toInternalDelete(Tracking tracking) => _HandleMessage(
        TrackingMessage(
          tracking.uuid,
          TrackingMessageType.deleted,
          tracking.toJson(),
        ),
        internal: true,
      );

  @override
  Stream<TrackingState> mapEventToState(TrackingCommand command) async* {
    try {
      if (command is LoadTrackings) {
        yield await _load(command);
      } else if (command is UpdateTracking) {
        yield await _update(command);
      } else if (command is DeleteTracking) {
        yield await _delete(command);
      } else if (command is UnloadTrackings) {
        yield await _unload(command);
      } else if (command is _HandleMessage) {
        yield* _process(command);
      } else if (command is RaiseTrackingError) {
        yield _toError(
          command,
          command.data,
        );
      } else {
        yield _toError(
          command,
          TrackingBlocError(
            "Unsupported $command",
            stackTrace: StackTrace.current,
          ),
        );
      }
    } on Exception catch (error, stackTrace) {
      yield _toError(
        command,
        TrackingBlocError(
          error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<TrackingState> _load(LoadTrackings command) async {
    var trackings = await repo.load(command.data);
    return _toOK(
      command,
      TrackingsLoaded(repo.keys),
      result: trackings,
    );
  }

  Future<TrackingState> _update(UpdateTracking command) async {
    final tracking = await repo.update(command.data);
    return _toOK(
      command,
      TrackingUpdated(tracking),
      result: tracking,
    );
  }

  Future<TrackingState> _delete(DeleteTracking command) async {
    final tracking = await repo.delete(command.data.uuid);
    return _toOK(
      command,
      TrackingDeleted(tracking),
      result: tracking,
    );
  }

  Future<TrackingState> _unload(UnloadTrackings command) async {
    final trackings = await repo.unload();
    return _toOK(
      command,
      TrackingsUnloaded(trackings),
      result: trackings,
    );
  }

  Stream<TrackingState> _process(_HandleMessage event) async* {
    switch (event.data.type) {
      case TrackingMessageType.created:
        final tracking = Tracking.fromJson(event.data.json);
        await (event.internal
            // Force local state
            ? repo.commit(StorageState.created(tracking))
            // Commit remote state
            : repo.commit(StorageState.pushed(tracking)));
        yield TrackingCreated(tracking);
        break;
      case TrackingMessageType.updated:
        final tracking = repo[event.data.uuid];
        if (tracking != null) {
          // Merge with existing
          final next = Tracking.fromJson(event.data.json);
          await (event.internal
              // Replace local value
              ? repo.replace(event.data.uuid, next)
              // Commit remote state
              : repo.commit(StorageState.pushed(tracking)));
          yield TrackingUpdated(next);
        }
        break;
      case TrackingMessageType.deleted:
        final tracking = repo[event.data.uuid];
        if (tracking != null) {
          final next = TrackingUtils.close(tracking);
          await (event.internal
              // Force deleted as local value
              ? repo.commit(StorageState<Tracking>.deleted(next))
              // Commit remote state
              : repo.commit(StorageState.pushed(tracking)));
          yield TrackingDeleted(next);
        }
        break;
      default:
        throw TrackingBlocException(
          "Tracking message not recognized",
          state,
          command: event,
          stackTrace: StackTrace.current,
        );
    }
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(TrackingCommand<Object, T> command) {
    add(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  Future<TrackingState> _toOK<T>(TrackingCommand event, TrackingState state, {T result}) async {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  TrackingState _toError(TrackingCommand event, Object error) {
    final object = error is TrackingBlocError
        ? error
        : TrackingBlocError(
            error,
            stackTrace: StackTrace.current,
          );
    event.callback.completeError(
      object,
      object.stackTrace ?? StackTrace.current,
    );
    return object;
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    if (_subscriptions.isNotEmpty) {
      add(RaiseTrackingError(TrackingBlocError(
        error,
        stackTrace: stackTrace,
      )));
    } else {
      throw TrackingBlocException(
        error,
        state,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<T, R> extends Equatable {
  final T data;
  final Completer<R> callback = Completer();

  TrackingCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadTrackings extends TrackingCommand<String, List<Tracking>> {
  LoadTrackings(String iuuid) : super(iuuid);

  @override
  String toString() => 'LoadTrackings {iuuid: $data}';
}

class UpdateTracking extends TrackingCommand<Tracking, Tracking> {
  UpdateTracking(Tracking data) : super(data);

  @override
  String toString() => 'UpdateTracking {data: $data}';
}

/// Command for processing a [TrackingMessage]. Each [TrackingMessage]
/// is committed to [repo] directly without any side effects
class _HandleMessage extends TrackingCommand<TrackingMessage, void> {
  final bool internal;
  _HandleMessage(TrackingMessage data, {@required this.internal}) : super(data);

  @override
  String toString() => '_HandleMessage {message: $data, local: $internal}';
}

class DeleteTracking extends TrackingCommand<Tracking, void> {
  DeleteTracking(Tracking data) : super(data);

  @override
  String toString() => 'DeleteTracking {data: $data}';
}

class UnloadTrackings extends TrackingCommand<String, List<Tracking>> {
  UnloadTrackings(String iuuid) : super(iuuid);

  @override
  String toString() => 'UnloadTrackings {iuuid: $data}';
}

class RaiseTrackingError extends TrackingCommand<TrackingBlocError, TrackingBlocError> {
  RaiseTrackingError(Object error, {StackTrace stackTrace})
      : super(
          TrackingBlocError(error, stackTrace: stackTrace),
        );

  @override
  String toString() => 'RaiseTrackingError {error: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class TrackingState<T> extends Equatable {
  final T data;

  TrackingState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is TrackingsEmpty;

  isLoaded() => this is TrackingsLoaded;

  isCreated() => this is TrackingCreated;

  isUpdated() => this is TrackingUpdated;

  isDeleted() => this is TrackingDeleted;

  isUnloaded() => this is TrackingsUnloaded;

  isError() => this is TrackingBlocError;
}

class TrackingsEmpty extends TrackingState<Null> {
  TrackingsEmpty() : super(null);

  @override
  String toString() => 'TrackingsEmpty';
}

class TrackingsLoaded extends TrackingState<List<String>> {
  TrackingsLoaded(List<String> data) : super(data);

  @override
  String toString() => 'TrackingLoaded {trackings: $data}';
}

class TrackingCreated extends TrackingState<Tracking> {
  TrackingCreated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingCreated {tracking: $data}';
}

class TrackingUpdated extends TrackingState<Tracking> {
  TrackingUpdated(Tracking data) : super(data);

  @override
  String toString() => 'TrackingUpdated {tracking: $data}';
}

class TrackingDeleted extends TrackingState<Tracking> {
  TrackingDeleted(Tracking data) : super(data);

  @override
  String toString() => 'TrackingDeleted {tracking: $data}';
}

class TrackingsUnloaded extends TrackingState<List<Tracking>> {
  TrackingsUnloaded(List<Tracking> tracks) : super(tracks);

  @override
  String toString() => 'TrackingCleared {trackings: $data}';
}

/// ---------------------
/// Error States
/// ---------------------

class TrackingBlocError extends TrackingState<Object> {
  final StackTrace stackTrace;

  TrackingBlocError(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => '$runtimeType {data: $data, stackTrace: $stackTrace}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class TrackingBlocException implements Exception {
  TrackingBlocException(this.error, this.state, {this.command, this.stackTrace});

  final Object error;
  final Object command;
  final TrackingState state;
  final StackTrace stackTrace;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}

/// ------------------------------------------
/// Helper class for querying tracked entities
/// ------------------------------------------
class Entities<T> {
  final TrackingBloc bloc;
  final Map<String, T> _data;
  final String Function(T entity) asId;

  Entities({
    /// [TrackingBloc] managing tracking objects
    @required this.bloc,

    /// Mapping from entity id to value object
    @required Map<String, T> data,

    /// Mapping from entity to tracking id
    @required this.asId,
  }) : this._data = data;

  /// Test if entity is being tracked
  bool contains(
    T entity, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      asId(entity) != null &&
      bloc.trackings.containsKey(asId(entity)) &&
      !exclude.contains(bloc.trackings[asId(entity)].status);

  /// Get entry with given tracking id
  T elementAt(
    String tracking, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      _data.values.firstWhere(
        (entity) => contains(entity, exclude: exclude) && tracking == asId(entity),
        orElse: () => null,
      );

  /// Find entity tracking given device
  T find(
    Device device, {
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      asTrackingIds(exclude: exclude).values.firstWhere(
            (entity) =>
                null !=
                bloc.devices(asId(entity), exclude: exclude).firstWhere(
                      (match) => device.uuid == match.uuid,
                      orElse: () => null,
                    ),
            orElse: () => null,
          );

  /// Get entities being tracked as a map of tracking id to entity object
  Map<String, T> asTrackingIds({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      UnmodifiableMapView(
        Map.fromEntries(
          _data.entries.where((entry) => contains(entry.value, exclude: exclude)),
        ),
      );

  /// Get entities for all tracked devices.
  Map<String, T> asDeviceIds({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String, T> map = {};
    asTrackingIds(exclude: exclude).values.forEach((entity) {
      bloc.devices(asId(entity), exclude: exclude).forEach((device) {
        map.update(device.uuid, (set) => entity, ifAbsent: () => entity);
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Get devices being tracked by entities of given type
  Map<String, Device> devices({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      UnmodifiableMapView(
        Map.fromEntries(
          _data.values
              .where((entity) => contains(entity, exclude: exclude))
              .map((entry) => bloc.trackings[asId(entry)]?.sources ?? [])
              .reduce((l1, l2) => List.from(l1)..addAll(l2))
              .where((source) => bloc.deviceBloc.repo.containsKey(source.uuid))
              .map((source) => MapEntry(source.uuid, bloc.deviceBloc.repo[source.uuid])),
        ),
      );
}
