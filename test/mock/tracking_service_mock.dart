

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_track_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

class TrackingBuilder {
  static Tracking create({
    String? uuid,
    Position? position,
    List<TrackingSource> sources = const [],
    List<TrackingTrack> tracks = const [],
    List<Position> history = const [],
    TrackingStatus status = TrackingStatus.ready,
  }) {
    final tracking = TrackingModel.fromJson(
      createAsJson(
        uuid ?? Uuid().v4(),
        position: position,
        status: status,
        tracks: tracks.map((p) => jsonEncode(p.toJson())).toList(),
        sources: sources.map((p) => jsonEncode(p.toJson())).toList(),
        history: history.map((p) => jsonEncode(p.toJson())).toList(),
      )!,
    );
    return tracking;
  }

  static Map<String, dynamic>? createAsJson(
    String uuid, {
    Position? position,
    List<String> sources = const [],
    List<String> tracks = const [],
    List<String> history = const [],
    TrackingStatus status = TrackingStatus.ready,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"status": "${enumName(status)}",'
        '"distance": 0,'
        '"sources": [${sources != null ? sources.join(',') : ''}],'
        '"tracks": [${tracks != null ? tracks.join(',') : ''}],'
        '"history": [${history != null ? history.join(',') : ''}]'
        '${position != null ? '", position": "${position.toJson()}"' : ''}'
        '}');
  }

  static double? nextDouble(rnd, double fraction, {negative: true}) {
    return (negative ? (-100 + rnd.nextInt(200)).toDouble() : rnd.nextInt(100)) / 100 * fraction;
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  TrackingServiceMock({this.simulate = false});
  final bool simulate;

  Tracking add(
    String? ouuid, {
    String? uuid,
    List<TrackingSource> sources = const [],
    List<TrackingTrack> tracks = const [],
    List<Position> history = const [],
    TrackingStatus status = TrackingStatus.ready,
  }) {
    final tracking = TrackingBuilder.create(
      uuid: uuid,
      sources: sources,
      tracks: tracks,
      history: history,
      status: status,
    );
    return put(ouuid, tracking);
  }

  Tracking put(String? ouuid, Tracking tracking) {
    final state = StorageState.created(
      tracking,
      StateVersion.first,
      isRemote: true,
    );
    if (trackingsRepo.containsKey(ouuid)) {
      trackingsRepo[ouuid]!.putIfAbsent(tracking.uuid, () => state);
    } else {
      trackingsRepo[ouuid] = {tracking.uuid: state};
    }
    return tracking;
  }

  List<StorageState<Tracking>?> remove(String uuid) {
    final ouuids = trackingsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return ouuids
        .map((ouuid) => trackingsRepo[ouuid as String]!.remove(uuid))
        .where(
          (unit) => unit != null,
        )
        .toList();
  }

  void reset() {
    s2t.clear();
    simulations.clear();
    trackingsRepo.clear();
    controller.close();
  }

  final Map<String?, String?> s2t = {}; // suuid -> tuuid
  final Map<String?, _TrackSimulation> simulations = {}; // tuuid -> simulation
  final Map<String?, Map<String?, StorageState<Tracking>>> trackingsRepo = {}; // ouuid -> tuuid -> tracking
  final StreamController<TrackingMessage> controller = StreamController.broadcast();

  factory TrackingServiceMock.build(
    DeviceRepository? devices, {
    int? personnelCount,
    int? unitCount,
    bool simulate = false,
    List<String> ouuids = const [],
  }) {
    final TrackingServiceMock mock = TrackingServiceMock(simulate: simulate);

    // Only generate tracking for automatically generated incidents
    ouuids.forEach((ouuid) {
      if (ouuid.startsWith('a:')) {
        final trackings = mock.trackingsRepo.putIfAbsent(ouuid, () => {});
        // Create unit tracking
        trackings.addEntries(
          _createTrackingUnits(
            ouuid,
            mock.s2t,
            unitCount!,
          ),
        );

        // Create personnel tracking
        trackings.addEntries(
          _createTrackingPersonnel(
            ouuid,
            mock.s2t,
            personnelCount!,
          ),
        );

        // Create simulations?
        if (simulate) {
          trackings.keys.forEach(
            (uuid) => _simulate(
              uuid,
              trackings,
              devices!.map,
              mock.simulations,
            ),
          );
        }
        mock.trackingsRepo.putIfAbsent(ouuid, () => trackings);
      }
    });

    if (simulate) {
      devices!.service.messages.listen((message) => _handle(
            message,
            mock.s2t,
            mock.trackingsRepo,
            mock.simulations,
            mock.controller,
          ));
    }

    when(mock.messages).thenAnswer(
      (_) => mock.controller.stream,
    );

    when(mock.getFromId(any)).thenAnswer((_) async {
      final String? tuuid = _.positionalArguments[0] as String?;
      final match = mock.trackingsRepo.entries.where((entry) => entry.value.containsKey(tuuid)).firstOrNull as MapEntry<String, Map<String, StorageState<Tracking>>>?;
      if (match != null) {
        return ServiceResponse.ok(
          body: match.value[tuuid!],
        );
      }
      return ServiceResponse.notFound(
        message: "Tracking $tuuid not found",
      );
    });

    when(mock.getListFromId(any)).thenAnswer((_) async {
      final String? ouuid = _.positionalArguments[0] as String?;
      if (mock.trackingsRepo.containsKey(ouuid)) {
        return ServiceResponse.ok(
          body: mock.trackingsRepo[ouuid]!.values.toList(),
        );
      }
      return ServiceResponse.ok(
        body: <StorageState<Tracking>>[],
      );
    });

    when(mock.update(isA<Tracking>())).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Tracking>;
      final tracking = next.value;
      final tuuid = tracking.uuid;
      final match = mock.trackingsRepo.entries.where((entry) => entry.value.containsKey(tuuid)).firstOrNull as MapEntry<String, Map<String?, StorageState<Tracking>>>?;
      if (match != null) {
        final trackingRepo = match.value;
        final state = trackingRepo[tuuid]!;
        final delta = next.version!.value! - state.version!.value!;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version! + 1}, actual was ${next.version}",
          );
        }
        final original = state.value;
        // Ensure only valid statuses are persisted
        var tracking = next.value.copyWith(
            status: _toStatus(
          next.value.status,
          next.value.sources.isNotEmpty == true,
        ));

//        // Append position to history if manual and does not exist in track
//        if (tracking.position != null && !tracking.history.contains(tracking.position)) {
//          if (tracking.position?.source == PositionSource.manual) {
//            tracking = tracking.cloneWith(position: request.position, history: tracking.history..add(request.position));
//          } else {
//            return _toOnlyManualResponse(request.position);
//          }
//        }

        final sources = next.value.sources.where(
          ((source) => !original.sources.contains(source) && mock.s2t.containsKey(source)),
        );
        if (sources.isNotEmpty) {
          return ServiceResponse.badRequest<StorageState<Tracking>>(
            message: "Bad request: Sources $sources are tracked already",
          );
        }

        // Update tracking repo
        trackingRepo.update(
          tracking.uuid,
          (_) => next.replace(
            tracking,
            isRemote: true,
          ),
          ifAbsent: () => next.replace(
            tracking,
            isRemote: true,
          ),
        );

        // Remove all and add again
        mock.s2t.removeWhere((_, tuuid) => tuuid == tracking.uuid);
        mock.s2t.addEntries(
          tracking.sources.map((source) => MapEntry(source.uuid, tracking.uuid)),
        );

        // Update simulation?
        if (simulate) {
          _simulate(
            tracking.uuid,
            trackingRepo,
            devices!.map,
            mock.simulations,
          );
        }

        trackingRepo[tuuid] = state.apply(
          tracking,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: trackingRepo[tuuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Tracking $tuuid not found",
      );
    });

    return mock;
  }

  static Iterable<MapEntry<String?, StorageState<Tracking>>> _createTrackingPersonnel(
    String ouuid,
    Map<String?, String?> s2t, // suuid -> tuuid
    int count,
  ) {
    // Track devices from app-series (tracking ouuid:t:p:$i -> device ouuid:d:a:$i)
    final tracking = _createTrackings(ouuid, 'p', 'd:a', count);
    // Map device ouuid:d:a:$i -> tracking ouuid:t:p:$i
    _addEntries(ouuid, 'd:a', s2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String?, StorageState<Tracking>>> _createTrackingUnits(
    String ouuid,
    Map<String?, String?> s2t, // suuid -> tuuid
    int unitCount,
  ) {
    // Track devices from tetra-series (tracking ouuid:t:u:$i -> device ouuid:d:t:$i)
    final tracking = _createTrackings(ouuid, 'u', 'd:t', unitCount);
    // Map device ouuid:d:t:$i -> tracking ouuid:t:u:$i
    _addEntries(ouuid, 'd:t', s2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String?, StorageState<Tracking>>> _createTrackings<T>(
    String ouuid,
    String entity,
    String device,
    int count,
  ) {
    return [
      for (var i = 1; i <= count; i++)
        TrackingModel.fromJson(
          TrackingBuilder.createAsJson(
            "$ouuid:t:$entity:$i",
            status: TrackingStatus.tracking,
          )!,
        ).copyWith(
            sources: List.from([
          TrackingSourceModel(
            uuid: "$ouuid:$device:$i",
            type: SourceType.device,
          )
        ])),
    ].map(
      (tracking) => MapEntry(
        tracking.uuid,
        StorageState.created(
          tracking,
          StateVersion.first,
          isRemote: true,
        ),
      ),
    );
  }

  static void _addEntries(
    String ouuid,
    String type,
    Map<String?, String?> tracked,
    Iterable<MapEntry<String?, StorageState<Tracking>>> items,
  ) {
    int i = 0;
    tracked.addEntries(
      items.map((entry) => MapEntry("$ouuid:$type:${++i}", entry.key)),
    );
  }

  static TrackingStatus? _toStatus(TrackingStatus? status, bool hasSources) {
    return [TrackingStatus.none, TrackingStatus.ready].contains(status)
        ? (hasSources ? TrackingStatus.tracking : TrackingStatus.ready)
        : (hasSources ? TrackingStatus.tracking : (TrackingStatus.closed == status ? status : TrackingStatus.paused));
  }

  static Tracking? _simulate(
    String? uuid,
    Map<String?, StorageState<Tracking>> trackingList,
    Map<String?, Device> devices,
    Map<String?, _TrackSimulation> simulations,
  ) {
    var tracking = trackingList[uuid]?.value;
    if (tracking != null) {
      // Only simulate aggregated position for tracking with devices
      if ([
        TrackingStatus.ready,
        TrackingStatus.tracking,
        TrackingStatus.paused,
      ].contains(tracking.status)) {
        final simulation = _TrackSimulation(
          uuid: uuid,
          trackingList: trackingList,
          devices: devices,
        );
        tracking = simulation.progress();
        simulations.update(uuid, (_) => simulation, ifAbsent: () => simulation);
      } else {
        simulations.remove(uuid);
      }
    }
    return tracking;
  }

  static void _handle(
    DeviceMessage message,
    Map<String?, String?> s2t,
    Map<String?, Map<String?, StorageState<Tracking>>> trackingRepo,
    Map<String?, _TrackSimulation> simulations,
    StreamController<TrackingMessage> controller,
  ) {
    final device = DeviceModel.fromJson(message.data);
    if (s2t.containsKey(device.uuid)) {
      final tuuid = s2t[device.uuid];
      // Assumes that a device is attached to a single incident only
      final incident = trackingRepo.entries.firstWhereOrNull(
        (entry) => entry.value.containsKey(tuuid),
      );
      if (incident != null) {
        // 2) Append new position to track, calculate new position, update and notify
        _progress(
          device,
          incident.key,
          tuuid,
          s2t,
          simulations,
          trackingRepo,
          controller,
        );
      }
    }
  }

  static void _progress(
    Device device,
    String? ouuid,
    String? tuuid,
    Map<String?, String?> s2t,
    Map<String?, _TrackSimulation> simulations,
    Map<String?, Map<String?, StorageState<Tracking>>> trackingRepo,
    StreamController<TrackingMessage> controller,
  ) {
    // Calculate
    final simulation = simulations[tuuid];
    if (simulation != null) {
      // Update first order aggregates:
      // * device -> personnel
      // * device -> unit
      final s2a1 = _toAggregateIds(device.uuid, tuuid, trackingRepo[ouuid], s2t)
        ..forEach(
          (suuid, auuid) => _progress(
            device,
            ouuid,
            auuid,
            s2t,
            simulations,
            trackingRepo,
            controller,
          ),
        );

      // Update second order aggregates:
      // * personnel -> unit
      final s2a2 = _toAggregateIds(device.uuid, tuuid, trackingRepo[ouuid], s2a1)
        ..forEach(
          (suuid, auuid) => _progress(
            device,
            ouuid,
            auuid,
            s2t,
            simulations,
            trackingRepo,
            controller,
          ),
        );

      // Update device position
      simulation.devices[device.uuid] = device;

      // Append to track, calculate next position, effort and speed
      final trackingList = trackingRepo[ouuid]!;
      final next = simulation.progress(
        suuids: {...s2a1.keys, ...s2a2.keys, device.uuid},
      );
      trackingList.update(
          tuuid,
          (state) => state.apply(
                next,
                replace: false,
                isRemote: true,
              ),
          ifAbsent: () => StorageState.created(
                next,
                StateVersion.first,
                isRemote: true,
              ));
      trackingRepo.update(
        ouuid,
        (_) => trackingList,
      );

      // Notify listeners
      controller.add(
        TrackingMessage.updated(
          next,
          trackingList[tuuid]!.version!,
        ),
      );
    }
  }

  static Map<String?, String?> _toAggregateIds(
    String? suuid,
    String? tuuid,
    Map<String?, StorageState<Tracking>>? trackingList,
    Map<String?, String?> s2t,
  ) =>
      Map.fromEntries(s2t.entries.where((e) => tuuid == e.key).where(
            (e) => trackingList![e.key]
                !.value
                .sources
                // Only match aggregates
                .any((source) => SourceType.trackable == source.type && source.uuid == suuid),
          ));
}

class _TrackSimulation {
  final String? uuid;
  final Map<String?, Device> devices;
  final Map<String?, StorageState<Tracking>> trackingList;

  Tracking? get tracking => trackingList[uuid]?.value;

  _TrackSimulation({
    required this.uuid,
    required this.trackingList,
    required this.devices,
  });

  Tracking progress({
    Iterable<String?> suuids = const [],
  }) {
    final current = tracking!;
    if (current.status == TrackingStatus.tracking) {
      Position? position;
      double? distance;
      double? speed;
      Duration? effort;

      final sources = current.sources;

      // Not tracking?
      if (sources.isEmpty) {
        position = current.position;
      }
      // Tracking one device only?
      else if (sources.length == 1) {
        position = _fromDevice(sources.first.uuid) ?? current.position;
      } else {
        // Calculate geometric centre of all devices and personnel as the arithmetic mean of the input coordinates
        var sum = [0.0, 0.0, 0.0, DateTime.now().millisecondsSinceEpoch].toList();
        sum = sources.fold<List<num>>(sum, (sum, next) => _aggregate(sum, _toPosition(next)));
        position = Position.timestamp(
          lat: sum[0] / sources.length,
          lon: sum[1] / sources.length,
          timestamp: DateTime.fromMillisecondsSinceEpoch(sum[3] as int),
          acc: sum[2] / sources.length,
        );
      }

      // Only add updated positions to tracks
      final updated = sources.where((source) => suuids.contains(source.uuid));
      final tracks = current.tracks.where((track) => updated.contains(track.source))
        ..map((track) {
          final positions = track.positions!.toList();
          final position = _toPosition(track.source);
          if (!positions.contains(position)) {
            return TrackingUtils.addUnique(track as TrackingTrackModel, position);
          }
          return track;
        });

      // Only add position if not added already
      List<Position?> history = current.history.contains(position) ? current.history : [...current.history, position];

      // Limit history and tracks to maximum 10 items each (prevent unbounded memory usage in long-running app)
      history = history.skip(max(0, history.length - 10)).toList();

      // Calculate effort, distance and speed
      if (history.length > 1) {
        effort = TrackingUtils.effort(history);
        distance = current.distance == null ? distance : TrackingUtils.distance(history, distance: current.distance!);
        speed = TrackingUtils.speed(distance!, effort);
      }

      return current.copyWith(
        position: position,
        distance: distance ?? 0.0,
        speed: speed ?? 0.0,
        effort: effort ?? Duration.zero,
        history: history,
        tracks: tracks.map((track) => track.truncate(10)).toList(),
      );
    }
    return current;
  }

  Position? _toPosition(TrackingSource source) =>
      SourceType.device == source.type ? _fromDevice(source.uuid) : _fromAggregate(source.uuid);

  Position? _fromDevice(String? uuid) => devices[uuid]?.position;
  Position? _fromAggregate(String? uuid) => trackingList[uuid]?.value.position;

  List<num> _aggregate(List<num> sum, Position? position) => position == null
      ? sum
      : [
          position.lat! + sum[0],
          position.lon! + sum[1],
          (position.acc ?? 0.0) + sum[2],
          min(position.timestamp!.millisecondsSinceEpoch, sum[3])
        ];
}
