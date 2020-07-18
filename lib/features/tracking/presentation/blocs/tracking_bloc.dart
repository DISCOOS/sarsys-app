import 'dart:async';
import 'dart:collection';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/blocs/mixins.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:flutter/foundation.dart';

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc extends BaseBloc<TrackingCommand, TrackingState, TrackingBlocError>
    with LoadableBloc<List<Tracking>>, UnloadableBloc<List<Tracking>>, ConnectionAwareBloc {
  ///
  /// Default constructor
  ///
  TrackingBloc(
    this.repo, {
    @required this.operationBloc,
    @required this.deviceBloc,
    @required this.unitBloc,
    @required this.personnelBloc,
  }) {
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(unitBloc != null, "unitBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    assert(deviceBloc != null, "deviceBloc can not be null");

    registerStreamSubscription(
      // Load and unload trackings as needed
      operationBloc.listen(_processIncidentState),
    );
    registerStreamSubscription(
      // Updates tracking for unit
      // apriori to changes made in backend.
      unitBloc.listen(_processUnitState),
    );
    registerStreamSubscription(
      // Updates tracking for personnel
      // apriori to changes made in backend.
      personnelBloc.listen(_processPersonnelState),
    );
    registerStreamSubscription(
      // Updates tracking for device
      // apriori to changes made in backend.
      deviceBloc.listen(_processDeviceState),
    );
    registerStreamSubscription(
      // Update from messages pushed from backend
      service.messages.listen(_processMessage),
    );
  }

  /// All repositories
  Iterable<ConnectionAwareRepository> get repos => [repo];

  /// Get [OperationBloc]
  final OperationBloc operationBloc;

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

  /// [Operation] that manages given [devices]
  String get ouuid => repo.ouuid;

  /// Check if [Operation.uuid] is not set
  bool get isUnset => repo.ouuid == null;

  /// Check if repository is offline
  bool get isOffline => repo.isOffline;

  @override
  TrackingState get initialState => TrackingsEmpty();

  /// Process [OperationState] events
  ///
  /// Invokes [load] and [unload] as needed.
  ///
  void _processIncidentState(OperationState state) {
    try {
      if (hasSubscriptions) {
        if (state.shouldLoad(ouuid)) {
          dispatch(LoadTrackings(state.data.uuid));
        } else if (state.shouldUnload(ouuid) && repo.isReady) {
          dispatch(UnloadTrackings(ouuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
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
  void _processDeviceState(DeviceState state) {
    try {
      if (state.isLocationChanged() || state.isStatusChanged()) {
        final device = state.data as Device;
        final trackings = find(device, tracks: true);
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
      Catcher.reportCheckedError(error, stackTrace);
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
  /// if [Unit.status] has changed to [UnitStatus.retired],
  /// or change to a status deferred from [Unit.status].
  ///
  /// Event [UnitDeleted] will delete associated [Tracking].
  ///
  void _processUnitState(UnitState state) {
    try {
      if (state.isCreated() && state.isTracked() && !state.isRetired()) {
        final created = (state as UnitCreated);
        final unit = created.data;
        final tracking = TrackingUtils.create(
          unit,
          sources: [
            ...TrackingUtils.toSources<Personnel>(personnelBloc.getAll(unit.personnels), repo),
            ...TrackingUtils.toSources<Device>(created.devices, repo),
          ],
        );
        // TODO: Backend will perform this apriori
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
          // TODO: Backend will perform this apriori
          add(_toInternalCreate(
            tracking,
          ));
        }
      } else if (state.isDeleted()) {
        final unit = (state as UnitDeleted).data;
        final tracking = repo[unit.tracking?.uuid];
        if (tracking != null) {
          // TODO: Backend will perform this apriori
          add(_toInternalDelete(
            tracking,
          ));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
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
  /// if [Personnel.status] has changed to [PersonnelStatus.retired],
  /// or change to a status deferred from [Personnel.status].
  ///
  /// Event [PersonnelDeleted] will delete associated [Tracking].
  ///
  void _processPersonnelState(PersonnelState state) {
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
      Catcher.reportCheckedError(error, stackTrace);
    }
  }

  /// Dispatches [TrackingMessage]s from
  /// [TrackingService] as an internal [_HandleMessage]
  /// command processed by method [_process]
  void _processMessage(TrackingMessage event) {
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
  TrackableQuery<Unit> get units => TrackableQuery<Unit>(
        bloc: this,
        data: this.unitBloc.units,
      );

  /// Get [personnels] being tracked
  TrackableQuery<Personnel> get personnels => TrackableQuery<Personnel>(
        bloc: this,
        data: this.personnelBloc.repo.map,
      );

  /// Test if [aggregate] is being tracked
  ///
  /// If [tracks] is [true] search is performed
  /// on `Tracking.tracks[].source.uuid` instead
  /// of `Tracking.sources[].uuid` (default is false).
  ///
  /// Returns empty list if [source.uuid] is not found
  /// for given set of excluded [TrackingStatus.values].
  ///
  bool has(
    Aggregate aggregate, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      repo.has(aggregate.uuid, tracks: tracks, exclude: exclude);

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
      repo.findTracingFrom(
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
    if (operationBloc.isUnselected) {
      throw TrackingBlocException(
        "No incident selected. Ensure that "
        "'IncidentBloc.select(String uuid)' is called before 'TrackingBloc.load()'",
        state,
      );
    }
  }

  /// Use current ouuid if exists or selected ouuid from IncidentBloc if exists
  String _ensureIuuid() => ouuid ?? operationBloc.selected?.uuid;

  /// Load [trackings] from [service]
  Future<List<Tracking>> load() async {
    _assertState();
    return dispatch<List<Tracking>>(
      LoadTrackings(_ensureIuuid()),
    );
  }

  /// Attach [devices] and [personnels] to given [Tracking.uuid]
  Future<Tracking> attach(
    String tuuid, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<Personnel> personnels,
  }) {
    final tracking = _assertExists(tuuid);
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
    return dispatch<Tracking>(
      UpdateTracking(
        TrackingUtils.calculate(
          next,
          status: status,
          position: position?.cloneWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
      ),
    );
  }

  /// Replace [devices] and [personnels] in given given [Tracking.uuid]
  ///
  /// Only [devices] and [personnels] already attached are replaced.
  Future<Tracking> replace(
    String tuuid, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<String> personnels,
  }) {
    final tracking = _assertExists(tuuid);
    final sources = _toSources(
      devices,
      personnelBloc.getAll(personnels ?? <String>[]),
    );
    final next = sources == null
        ? tracking
        : TrackingUtils.replaceAll(
            tracking,
            sources,
            calculate: false,
          );
    return dispatch<Tracking>(
      UpdateTracking(
        TrackingUtils.calculate(
          next,
          status: status,
          position: position?.cloneWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
      ),
    );
  }

  /// Detach [devices] and [personnels] from given [Tracking.uuid]
  Future<Tracking> detach(
    String tuuid, {
    Position position,
    TrackingStatus status,
    List<Device> devices,
    List<Personnel> personnels,
  }) {
    final tracking = _assertExists(tuuid);
    final sources = _toSources(
      devices,
      personnels,
    );
    final next = sources == null
        ? tracking
        : TrackingUtils.detachAll(
            tracking,
            sources.map((s) => s.uuid),
            calculate: false,
          );
    return dispatch<Tracking>(
      UpdateTracking(
        TrackingUtils.calculate(
          next,
          status: status,
          position: position?.cloneWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
      ),
    );
  }

  /// Update given [Tracking.uuid]
  Future<Tracking> update(
    String tuuid, {
    Position position,
    TrackingStatus status,
  }) {
    final tracking = _assertExists(tuuid);
    return dispatch<Tracking>(
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

  List<PositionableSource<Aggregate>> _toSources(List<Device> devices, List<Personnel> personnels) {
    final replaceDevices = devices != null;
    final replacePersonnel = personnels != null;
    final sources = [
      if (replaceDevices) ...TrackingUtils.toSources(devices, repo),
      if (replacePersonnel) ...TrackingUtils.toSources(personnels, repo),
    ];
    return sources;
  }

  /// Unload [trackings] from local storage
  Future<List<Tracking>> unload() {
    _assertState();
    return dispatch<List<Tracking>>(
      UnloadTrackings(ouuid),
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
  Stream<TrackingState> execute(TrackingCommand command) async* {
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
    } else {
      yield toUnsupported(command);
    }
  }

  Future<TrackingState> _load(LoadTrackings command) async {
    var trackings = await repo.load(command.data);
    return toOK(
      command,
      TrackingsLoaded(repo.keys),
      result: trackings,
    );
  }

  Future<TrackingState> _update(UpdateTracking command) async {
    final tracking = await repo.update(command.data);
    return toOK(
      command,
      TrackingUpdated(tracking),
      result: tracking,
    );
  }

  Future<TrackingState> _delete(DeleteTracking command) async {
    final tracking = await repo.delete(command.data.uuid);
    return toOK(
      command,
      TrackingDeleted(tracking),
      result: tracking,
    );
  }

  Future<TrackingState> _unload(UnloadTrackings command) async {
    final trackings = await repo.close();
    return toOK(
      command,
      TrackingsUnloaded(trackings),
      result: trackings,
    );
  }

  Stream<TrackingState> _process(_HandleMessage event) async* {
    if (!repo.isReady) return;
    final remote = !event.internal;
    switch (event.data.type) {
      case TrackingMessageType.created:
        var next;
        final current = repo.states[event.data.uuid];
        if (current == null) {
          // Not found
          next = Tracking.fromJson(event.data.json);
          repo.put(
            StorageState.created(next, remote: remote),
          );
        } else {
          next = _merge(current, event);
          if (current.isLocal) {
            // Replace local value
            repo.replace(event.data.uuid, next, remote: remote);
          } else {
            // Commit remote state
            repo.put(StorageState.created(next, remote: remote));
          }
        }
        yield TrackingCreated(next);
        break;
      case TrackingMessageType.updated:
        final current = repo.states[event.data.uuid];
        if (current != null) {
          Tracking next = _merge(current, event);
          if (current.isLocal) {
            // Replace local value
            repo.replace(event.data.uuid, next, remote: !event.internal);
          } else {
            // Commit remote state
            repo.put(StorageState.updated(next, remote: remote));
          }
          yield TrackingUpdated(next);
        }
        break;
      case TrackingMessageType.deleted:
        final tracking = repo[event.data.uuid];
        if (tracking != null) {
          final next = TrackingUtils.close(tracking);
          repo.put(
            StorageState.deleted(next, remote: remote),
          );
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

  Tracking _merge(StorageState<Tracking> current, _HandleMessage event) {
    final json = JsonUtils.patch(
      current.value,
      Tracking.fromJson(event.data.json),
    );
    final next = Tracking.fromJson(json);
    return next;
  }

  Tracking _assertExists(String tuuid) {
    final tracking = repo[tuuid];
    if (tracking == null) {
      throw TrackingNotFoundException(tuuid, state);
    }
    return tracking;
  }

  @override
  TrackingBlocError createError(Object error, {StackTrace stackTrace}) => TrackingBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  @override
  Future<void> close() async {
    await repo.dispose();
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<D, R> extends BlocCommand<D, R> {
  TrackingCommand(
    D data, {
    props = const [],
  }) : super(data, props);
}

class LoadTrackings extends TrackingCommand<String, List<Tracking>> {
  LoadTrackings(String ouuid) : super(ouuid);

  @override
  String toString() => 'LoadTrackings {ouuid: $data}';
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
  UnloadTrackings(String ouuid) : super(ouuid);

  @override
  String toString() => 'UnloadTrackings {ouuid: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class TrackingState<T> extends BlocEvent<T> {
  TrackingState(
    Object error, {
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);

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
  final Object command;
  final TrackingState state;
  final StackTrace stackTrace;

  @override
  String toString() => '$runtimeType {error: $error, state: $state, command: $command, stackTrace: $stackTrace}';
}

/// -------------------------------------------------
/// Helper class for querying [Trackable] aggregates
/// -------------------------------------------------
class TrackableQuery<T extends Trackable> {
  final TrackingBloc bloc;
  final Map<String, T> _data;

  TrackableQuery({
    /// [TrackingBloc] managing tracking objects
    @required this.bloc,

    /// Mapping from [Aggregate.uuid] to Aggregate of type [T]
    @required Map<String, T> data,
  }) : this._data = UnmodifiableMapView(_toTracked(data, bloc.repo));

  static Map<String, T> _toTracked<String, T extends Trackable>(Map<String, T> data, TrackingRepository repo) {
    return Map.from(data)..removeWhere((_, trackable) => !repo.containsKey(trackable.tracking.uuid));
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
  Iterable<Tracking> get trackings => _data.keys.map((tuuid) => bloc.repo[tuuid]);

  /// Test if given [trackable] is a source in any [Tracking] in this [TrackableQuery]
  bool contains(T trackable) => _data.containsKey(trackable.uuid);

  /// Get [Tracking] from given [Trackable] of type [T]
  Tracking elementAt(T trackable) => bloc.repo[trackable.tracking.uuid];

  /// Get aggregate of type [T] tracked by given [Tracking.uuid]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping if found.
  ///
  T trackedBy(String tuuid) => _data.values.firstWhere(
        (trackable) => trackable.tracking.uuid == tuuid,
        orElse: () => null,
      );

  /// Find aggregate of type [T] tracking [tracked]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  T find(
    Aggregate tracked, {
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
      found = where(exclude: exclude).trackables.firstWhere(
            (trackable) =>
                bloc.repo[trackable.tracking?.uuid]?.sources?.any(
                  (source) => source.uuid == tracked.uuid,
                ) ??
                false,
            orElse: () => null,
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
          ),
        ),
      );

  /// Get map of [Device.uuid] to tracked by aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  Map<String, T> devices({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String, T> map = {};
    trackables.forEach((trackable) {
      bloc.devices(trackable.tracking.uuid).forEach((device) {
        map.update(device.uuid, (set) => trackable, ifAbsent: () => trackable);
      });
    });
    return UnmodifiableMapView(map);
  }

  /// Get map of [Personnel.uuid] to tracked by aggregate of type [T]
  ///
  /// The 'only one active tracking for each source'
  /// rule guarantees a one-to-one mapping.
  ///
  /// Only aggregates of type [Unit] are allowed to track
  /// [Personnel]. The [Tracking] referenced by [Unit] will
  /// append the [Tracking.position] of the [Tracking]
  /// referenced by [Personnel].
  ///
  Map<String, T> personnels({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String, T> map = {};
    final personnels = bloc.personnels.where(exclude: exclude);
    // For each Unit
    trackables.forEach((trackable) {
      // Find tracking of unit
      final tracking = elementAt(trackable);
      // Collect tracking of personnels
      tracking.sources
          // Only consider personnels that exists
          .where((source) => personnels.map.containsKey(source.uuid))
          // Get personnel from source uuid
          .map((source) => personnels.map[source.uuid])
          // Update mapping between personnel and trackable T
          .forEach(
            (personnel) => map.update(
              personnel.uuid,
              (set) => trackable,
              ifAbsent: () => trackable,
            ),
          );
    });
    return UnmodifiableMapView(map);
  }
}
