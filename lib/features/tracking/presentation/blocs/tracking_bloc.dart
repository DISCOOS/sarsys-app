

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';

import 'tracking_bloc_commands.dart';
import 'tracking_bloc_query.dart';
import 'tracking_bloc_states.dart';

export 'tracking_bloc_commands.dart';
export 'tracking_bloc_query.dart';
export 'tracking_bloc_states.dart';

typedef void TrackingCallback(VoidCallback fn);

class TrackingBloc
    extends StatefulBloc<TrackingCommand, TrackingState<Object>, TrackingBlocError, String, Tracking, TrackingService>
    with LoadableBloc<List<Tracking>?>, UnloadableBloc<List<Tracking>?> {
  ///
  /// Default constructor
  ///
  TrackingBloc(
    this.repo, {
    required this.operationBloc,
    required this.deviceBloc,
    required this.unitBloc,
    required this.personnelBloc,
    required BlocEventBus bus,
  }) : super(TrackingsEmpty(), bus: bus) {
    assert(service != null, "service can not be null");
    assert(operationBloc != null, "operationBloc can not be null");
    assert(unitBloc != null, "unitBloc can not be null");
    assert(personnelBloc != null, "personnelBloc can not be null");
    assert(deviceBloc != null, "deviceBloc can not be null");

    // Load and unload trackings as needed
    subscribe<OperationUpdated>(_processOperationState);
    subscribe<OperationSelected>(_processOperationState);
    subscribe<OperationUnselected>(_processOperationState);
    subscribe<OperationDeleted>(_processOperationState);

    // Notify when tracking state has changed
    forward(
      (t) => _NotifyRepositoryStateChanged(t as StorageTransition<Tracking>),
    );

    registerStreamSubscription(
      // Updates tracking for unit
      // apriori to changes made in backend.
      unitBloc.stream.where((e) => e.isLocal).listen(_processUnitState),
    );

    registerStreamSubscription(
      // Updates tracking for personnel
      // apriori to changes made in backend.
      personnelBloc!.stream.where((e) => e.isLocal).listen(_processPersonnelState),
    );

    registerStreamSubscription(
      // Updates tracking for device
      // apriori to changes made in backend.
      deviceBloc.stream.where((e) => e.isLocal).listen(_processDeviceState),
    );
  }

  /// Get [OperationBloc]
  final OperationBloc? operationBloc;

  /// Get [UnitBloc]
  final UnitBloc unitBloc;

  /// Get [PersonnelBloc]
  final PersonnelBloc? personnelBloc;

  /// Get [DeviceBloc]
  final DeviceBloc deviceBloc;

  /// Get [TrackingRepository]
  final TrackingRepository repo;

  /// Check if bloc is ready
  @override
  bool get isReady => repo.isReady;

  /// Stream of isReady changes
  @override
  Stream<bool> get onReadyChanged => repo.onReadyChanged;

  /// Check if [Operation.uuid] is not set
  bool get isUnset => repo.ouuid == null;

  /// [Operation] that manages given [tra]
  String? get ouuid => isReady ? (repo.ouuid ?? operationBloc!.selected?.uuid) : null;

  /// Process [OperationState] events
  ///
  /// Invokes [load] and [unload] as needed.
  ///
  void _processOperationState(BaseBloc bloc, OperationState state) async {
    try {
      // Only process local events
      if (isOpen && state.isLocal) {
        final unselected = (bloc as OperationBloc).isUnselected;
        if (state.shouldLoad(ouuid)) {
          await dispatch(
            LoadTrackings(state.data.uuid),
          );
        } else if (isReady && (unselected || state.shouldUnload(ouuid))) {
          await unload();
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
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
      if (isOpen) {
        switch (state.runtimeType) {
          case DeviceUpdated:
            _onDeviceUpdated(state as DeviceUpdated);
            break;
          case DeviceDeleted:
            _onDeviceDeleted(state);
            break;
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  void _onDeviceUpdated(DeviceUpdated state) {
    if (state.isLocationChanged() || state.isStatusChanged()) {
      final Device device = state.data;
      final trackings = find(device, tracks: true);
      if (trackings.isNotEmpty) {
        final next = state.isAvailable()
            ? TrackingUtils.attachAll(
                trackings.first!,
                [PositionableSource.from<Device>(device)],
              )
            : TrackingUtils.detachAll(
                trackings.first!,
                [device.uuid],
              );
        add(_toAprioriChange(next));
      }
    }
  }

  void _onDeviceDeleted(DeviceState state) {
    if (state.isDeleted()) {
      final device = state.data;
      final trackings = find(device);
      if (trackings.isNotEmpty) {
        final next = TrackingUtils.deleteAll(
          trackings.first!,
          [device.uuid],
        );
        add(_toAprioriChange(next));
      }
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
      if (isOpen) {
        switch (state.runtimeType) {
          case UnitCreated:
            _onUnitCreated(state as UnitCreated);
            break;
          case UnitUpdated:
            _onUnitUpdated(state as UnitUpdated);
            break;
          case UnitDeleted:
            _onUnitDeleted(state as UnitDeleted);
            break;
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  void _onUnitCreated(UnitCreated state) {
    if (state.isTracked() && !state.isRetired()) {
      final Unit unit = state.data;
      final tracking = TrackingUtils.create(
        unit,
        sources: [
          ...TrackingUtils.toSources<Personnel>(personnelBloc!.from(unit.personnels) as Iterable<Personnel>?, repo),
          ...TrackingUtils.toSources<Device>(state.devices, repo),
        ],
      );
      // TODO: Backend will perform this apriori
      add(_toAprioriCreate(
        tracking,
      ));
    }
  }

  void _onUnitUpdated(UnitUpdated state) {
    if (state.isStatusChanged()) {
      final Unit unit = state.data;
      final tracking = repo[unit.tracking.uuid!];
      if (tracking != null) {
        final next = TrackingUtils.toggle(
          tracking,
          state.isRetired(),
        );
        // TODO: Backend will perform this apriori
        add(_toAprioriChange(
          next,
        ));
      } else if (!state.isRetired()) {
        // TODO: Backend will perform this apriori
        add(_toAprioriCreate(
          tracking!,
        ));
      }
    }
  }

  void _onUnitDeleted(UnitDeleted state) {
    final Unit unit = state.data;
    final tracking = repo[unit.tracking.uuid!];
    if (tracking != null) {
      // TODO: Backend will perform this apriori
      add(_toAprioriDelete(
        tracking,
      ));
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
      if (isOpen) {
        switch (state.runtimeType) {
          case UserMobilized:
          case PersonnelCreated:
            _onPersonnelCreated(state as PersonnelCreated);
            break;
          case PersonnelUpdated:
            _onPersonnelUpdated(state as PersonnelUpdated);
            break;
          case PersonnelDeleted:
            _onPersonnelDeleted(state as PersonnelDeleted);
            break;
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  void _onPersonnelCreated(PersonnelCreated state) {
    if (state.isTracked() && !state.isRetired()) {
      final Personnel? personnel = state.data;
      final tracking = TrackingUtils.create(personnel);
      // Backend will perform this apriori
      add(_toAprioriCreate(
        tracking,
      ));
    }
  }

  void _onPersonnelUpdated(PersonnelUpdated state) {
    if (state.isUpdated() && state.isStatusChanged()) {
      final Personnel personnel = state.data;
      final tracking = repo[personnel.tracking.uuid!];
      if (tracking != null) {
        final next = TrackingUtils.toggle(
          tracking,
          state.isRetired(),
        );
        // Backend will perform this apriori
        add(_toAprioriChange(
          next,
        ));
      }
    }
  }

  void _onPersonnelDeleted(PersonnelDeleted state) {
    if (state.isDeleted()) {
      final Personnel personnel = state.data!;
      final tracking = repo[personnel.tracking.uuid!];
      if (tracking != null) {
        // Backend will perform this apriori
        add(_toAprioriDelete(
          tracking,
        ));
      }
    }
  }

  /// Stream of tracking changes for test
  Stream<Tracking> onChanged(String? uuid, {bool skipPosition = false}) => stream
      .where(
        (state) =>
            (state is TrackingUpdated &&
                state.isChanged() &&
                (!skipPosition || !state.isLocationChanged()) &&
                state.data.uuid == uuid) ||
            (state is TrackingsLoaded && state.data.contains(uuid)),
      )
      .map((state) => (state is TrackingsLoaded ? repo[uuid!] : state.data)).where((t) => t is Tracking).map((t) => t as Tracking);

  /// Stream of tracking location changes for test
  Stream<Tracking> onMoved(String? uuid) => stream
      .where(
        (state) => (state is TrackingUpdated && state.isLocationChanged() && state.data.uuid == uuid),
      )
      .map((state) => state.data as Tracking);

  /// Get all tracking objects
  Map<String, Tracking> get trackings => repo.map;

  /// Get units being tracked
  TrackableQuery<Unit?> get units => TrackableQuery<Unit?>(
        bloc: this,
        data: this.unitBloc.units,
      );

  /// Get [personnels] being tracked
  TrackableQuery<Personnel?> get personnels => TrackableQuery<Personnel?>(
        bloc: this,
        data: this.personnelBloc!.repo.map,
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

  /// Find [Personnel]s available for tracking.
  Iterable<Personnel?> findAvailablePersonnel() {
    final query = units.personnels();
    return personnelBloc!.repo.values.where((personnel) => !query.containsKey(personnel.uuid));
  }

  /// Find [Device]s available for tracking.
  Iterable<Device> findAvailableDevices() {
    final queryUnits = units.devices();
    final queryPersonnels = personnels.devices();
    return deviceBloc.repo!.values.where(
      (device) => !(queryUnits.containsKey(device.uuid) || queryPersonnels.containsKey(device.uuid)),
    );
  }

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
  Iterable<Tracking?> find(
    Aggregate aggregate, {
    bool tracks = false,
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) =>
      repo.findTrackingFrom(
        aggregate.uuid,
        tracks: tracks,
        exclude: exclude,
      );

  /// Get devices being tracked by given [Tracking.uuid]
  List<Device> devices(
    String? tuuid, {
    List<TrackingStatus> exclude = const [TrackingStatus.closed],
  }) =>
      repo.containsKey(tuuid) && !exclude.contains(repo[tuuid!]!.status)
          ? repo[tuuid]!
              .sources
              .where((source) => deviceBloc.repo!.containsKey(source.uuid))
              .map((source) => deviceBloc.repo![source.uuid]!)
              .toList()
          : [];

  /// Get tracking for all tracked devices as a map from device id to all [Tracking] instances tracking the device
  Map<String?, Set<Tracking?>> asDeviceIds({
    List<TrackingStatus> exclude: const [TrackingStatus.closed],
  }) {
    final Map<String?, Set<Tracking?>> map = {};
    repo.values.where((tracking) => !exclude.contains(tracking.status)).forEach((tracking) {
      devices(tracking.uuid).forEach((device) {
        map.update(device.uuid, (set) => set..add(tracking), ifAbsent: () => {tracking});
      });
    });
    return UnmodifiableMapView(map);
  }

  void _assertState() {
    if (operationBloc!.isUnselected) {
      throw TrackingBlocException(
        "No incident selected. Ensure that "
        "'IncidentBloc.select(String uuid)' is called before 'TrackingBloc.load()'",
        state,
      );
    }
  }

  /// Load [trackings] from [service]
  Future<List<Tracking>?> load() async {
    _assertState();
    return dispatch<List<Tracking>>(
      LoadTrackings(ouuid ?? operationBloc!.selected?.uuid),
    );
  }

  /// Attach [devices] and [personnels] to given [Tracking.uuid]
  Future<Tracking?> attach(
    String? tuuid, {
    Position? position,
    TrackingStatus? status,
    List<Device>? devices,
    List<Personnel>? personnels,
  }) {
    final tracking = _ensureExists(tuuid);
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
          position: position?.copyWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
        tracking,
      ),
    );
  }

  /// Replace [devices] and [personnels] in given given [Tracking.uuid]
  ///
  /// Only [devices] and [personnels] already attached are replaced.
  Future<Tracking?> replace(
    String? tuuid, {
    Position? position,
    TrackingStatus? status,
    List<Device>? devices,
    List<String>? personnels,
  }) {
    final tracking = _ensureExists(tuuid);
    final sources = _toSources(
      devices,
      personnelBloc!.from(personnels ?? <String>[]) as List<Personnel>?,
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
          position: position?.copyWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
        tracking,
      ),
    );
  }

  /// Detach [devices] and [personnels] from given [Tracking.uuid]
  Future<Tracking?> detach(
    String? tuuid, {
    Position? position,
    TrackingStatus? status,
    List<Device>? devices,
    List<Personnel>? personnels,
  }) {
    final tracking = _ensureExists(tuuid);
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
          position: position?.copyWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
        tracking,
      ),
    );
  }

  /// Update given [Tracking.uuid]
  Future<Tracking?> update(
    String? tuuid, {
    Position? position,
    TrackingStatus? status,
  }) {
    final tracking = _ensureExists(tuuid);
    return dispatch<Tracking>(
      UpdateTracking(
        TrackingUtils.calculate(
          tracking,
          status: status,
          position: position?.copyWith(
            // Always manual when from outside
            source: PositionSource.manual,
          ),
        ),
        tracking,
      ),
    );
  }

  List<PositionableSource<Aggregate>> _toSources(List<Device>? devices, List<Personnel>? personnels) {
    final replaceDevices = devices != null;
    final replacePersonnel = personnels != null;
    final sources = [
      if (replaceDevices) ...TrackingUtils.toSources(devices, repo),
      if (replacePersonnel) ...TrackingUtils.toSources(personnels, repo),
    ];
    return sources;
  }

  /// Unload [trackings] from local storage
  Future<List<Tracking>?> unload() {
    return dispatch<List<Tracking>>(
      UnloadTrackings(ouuid),
    );
  }

  /// Create [_NotifyRepositoryStateChanged] for processing [TrackingMessageType.TrackingCreated]
  _HandleMessage _toAprioriCreate(Tracking tracking) => _HandleMessage(
        TrackingMessage.created(tracking, repo.getVersion(tracking.uuid)!),
      );

  /// Create [_NotifyRepositoryStateChanged] for processing [TrackingMessageType.TrackingInformationUpdated]
  _HandleMessage _toAprioriChange(Tracking tracking) => _HandleMessage(
        TrackingMessage.updated(tracking, repo.getVersion(tracking.uuid)!),
      );

  /// Create [_NotifyRepositoryStateChanged] for processing [TrackingMessageType.TrackingDeleted].
  _HandleMessage _toAprioriDelete(Tracking tracking) => _HandleMessage(
        TrackingMessage.deleted(tracking, repo.getVersion(tracking.uuid)!),
      );

  @override
  Stream<TrackingState<Object>> execute(TrackingCommand command) async* {
    if (command is LoadTrackings) {
      yield* _load(command);
    } else if (command is UpdateTracking) {
      yield* _update(command);
    } else if (command is DeleteTracking) {
      yield* _delete(command);
    } else if (command is UnloadTrackings) {
      yield await _unload(command);
    } else if (command is _NotifyRepositoryStateChanged) {
      yield _notify(command);
    } else if (command is _HandleMessage) {
      yield* _process(command);
    } else if (command is _NotifyBlocStateChanged) {
      yield command.data;
    } else {
      yield toUnsupported(command);
    }
  }

  Stream<TrackingState<Object>> _load(LoadTrackings command) async* {
    // Fetch cached and handle
    // response from remote when ready
    final onRemote = Completer<Iterable<Tracking>>();
    final trackings = await repo.load(
      command.data,
      onRemote: onRemote,
    );
    yield toOK(
      command,
      TrackingsLoaded(repo.keys as List<String>),
      result: trackings,
    );

    // Notify when states was fetched from remote storage
    onComplete(
      [onRemote.future],
      toState: (_) => TrackingsLoaded(
        repo.keys as List<String>,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<TrackingState<Object>> _update(UpdateTracking command) async* {
    final tracking = repo.apply(command.data);
    yield toOK(
      command,
      TrackingUpdated(
        tracking,
        command.previous,
      ),
      result: tracking,
    );

    // Notify when all states are remote
    onComplete(
      [repo.onRemote(tracking.uuid)],
      toState: (_) => TrackingUpdated(
        repo[tracking.uuid],
        tracking,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<TrackingState<Object>> _delete(DeleteTracking command) async* {
    final onRemote = Completer<Tracking>();
    final tracking = repo.delete(
      command.data.uuid,
      onResult: onRemote,
    );
    yield toOK(
      command,
      TrackingDeleted(tracking),
      result: tracking,
    );

    // Notify when all states are remote
    onComplete(
      [onRemote.future],
      toState: (_) => TrackingDeleted(
        tracking,
        isRemote: true,
      ),
      toCommand: (state) => _NotifyBlocStateChanged(state),
      toError: (error, stackTrace) => toError(
        command,
        error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<TrackingState<Object>> _unload(UnloadTrackings command) async {
    final List<Tracking?> trackings = await repo.close();
    return toOK(
      command,
      TrackingsUnloaded(trackings),
      result: trackings,
    );
  }

  TrackingState<Object> _notify(_NotifyRepositoryStateChanged command) {
    final Tracking tracking = command.state;

    switch (command.status) {
      case StorageStatus.created:
        return toOK(
          command,
          TrackingCreated(
            tracking,
            isRemote: command.isRemote,
          ),
          result: tracking,
        );
      case StorageStatus.updated:
        return toOK(
          command,
          TrackingUpdated(
            tracking,
            command.previous,
            isRemote: command.isRemote,
          ),
          result: tracking,
        );
      case StorageStatus.deleted:
        return toOK(
          command,
          TrackingDeleted(
            tracking,
            isRemote: command.isRemote,
          ),
          result: tracking,
        );
      default:
        return toError(
          command,
          'Unknown state status ${command.status}',
          stackTrace: StackTrace.current,
        );
    }
  }

  Stream<TrackingState<Object>> _process(_HandleMessage command) async* {
    if (!isReady) {
      yield state;
      return;
    }

    switch (command.data.type) {
      case TrackingMessageType.TrackingCreated:
      case TrackingMessageType.TrackingStatusChanged:
      case TrackingMessageType.TrackingInformationUpdated:
        final value = TrackingModel.fromJson(command.data.state!);
        final next = repo.patch(value, isRemote: false)!.value;
        yield command.data.type == TrackingMessageType.TrackingCreated
            ? TrackingCreated(next)
            : TrackingUpdated(
                next,
                value,
              );
        break;
      case TrackingMessageType.TrackingDeleted:
        final tracking = repo[command.data.uuid!];
        if (tracking != null) {
          final next = TrackingUtils.close(tracking);
          repo.remove(next, isRemote: false);
          yield TrackingDeleted(next);
        }
        break;
      default:
        throw TrackingBlocException(
          "Tracking message '${enumName(command.data.type)}' not recognized",
          state,
          command: command,
          stackTrace: StackTrace.current,
        );
    }
  }

  Tracking _ensureExists(String? tuuid) {
    final tracking = repo[tuuid!];
    if (tracking == null) {
      final state = StorageState.created(
        TrackingModel(
          uuid: tuuid,
          status: TrackingStatus.none,
        ),
        StateVersion.first,
        isRemote: false,
      );
      repo.put(state);
      return state.value;
    }
    return tracking;
  }

  @override
  TrackingBlocError createError(Object error, {StackTrace? stackTrace}) => TrackingBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}

/// ---------------------
/// Internal Commands
/// ---------------------

/// Command for processing a [TrackingMessage]. Each [TrackingMessage]
/// is committed to [repo] directly without any side effects
class _HandleMessage extends TrackingCommand<TrackingMessage, void> {
  _HandleMessage(TrackingMessage data) : super(data);

  @override
  String toString() => '$runtimeType {previous: $data, next: $data}';
}

class _NotifyRepositoryStateChanged extends TrackingCommand<StorageTransition<Tracking>, Tracking>
    with NotifyRepositoryStateChangedMixin {
  _NotifyRepositoryStateChanged(StorageTransition<Tracking> transition) : super(transition);
}

class _NotifyBlocStateChanged extends TrackingCommand<TrackingState<Object>, Object>
    with NotifyBlocStateChangedMixin<TrackingState<Object>, Object> {
  _NotifyBlocStateChanged(TrackingState<Object> state) : super(state);
}
