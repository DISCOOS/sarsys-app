import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Source.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';
import 'package:uuid/uuid.dart';

import 'devices.dart';

class TrackingBuilder {
  static Tracking create({
    String uuid,
    Position position,
    List<Source> sources = const [],
    List<Track> tracks = const [],
    List<Position> history = const [],
    TrackingStatus status = TrackingStatus.created,
  }) {
    final tracking = Tracking.fromJson(
      createAsJson(
        uuid ?? Uuid().v4(),
        position: position,
        status: status ?? TrackingStatus.created,
        tracks: (tracks ?? []).map((p) => jsonEncode(p.toJson())).toList(),
        sources: (sources ?? []).map((p) => jsonEncode(p.toJson())).toList(),
        history: (history ?? []).map((p) => jsonEncode(p.toJson())).toList(),
      ),
    );
    return tracking;
  }

  static Map<String, dynamic> createAsJson(
    String uuid, {
    Position position,
    List<String> sources = const [],
    List<String> tracks = const [],
    List<String> history = const [],
    TrackingStatus status = TrackingStatus.created,
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

  static double nextDouble(rnd, double fraction, {negative: true}) {
    return (negative ? (-100 + rnd.nextInt(200)).toDouble() : rnd.nextInt(100)) / 100 * fraction;
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  TrackingServiceMock({this.simulate = false});
  final bool simulate;

  Tracking add(
    String iuuid, {
    String uuid,
    List<Source> sources = const [],
    List<Track> tracks = const [],
    List<Position> history = const [],
    TrackingStatus status = TrackingStatus.created,
  }) {
    final tracking = TrackingBuilder.create(
      uuid: uuid,
      sources: sources,
      tracks: tracks,
      history: history,
      status: status,
    );
    return put(iuuid, tracking);
  }

  Tracking put(String iuuid, Tracking tracking) {
    if (trackingsRepo.containsKey(iuuid)) {
      trackingsRepo[iuuid].putIfAbsent(tracking.uuid, () => tracking);
    } else {
      trackingsRepo[iuuid] = {tracking.uuid: tracking};
    }
    return tracking;
  }

  List<Tracking> remove(String uuid) {
    final iuuids = trackingsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((iuuid) => trackingsRepo[iuuid].remove(uuid))
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

  final Map<String, String> s2t = {}; // suuid -> tuuid
  final Map<String, _TrackSimulation> simulations = {}; // tuuid -> simulation
  final Map<String, Map<String, Tracking>> trackingsRepo = {}; // iuuid -> tuuid -> tracking
  final StreamController<TrackingMessage> controller = StreamController.broadcast();

  factory TrackingServiceMock.build(
    DeviceServiceMock deviceServiceMock, {
    int personnelCount,
    int unitCount,
    bool simulate = false,
    List<String> iuuids = const [],
  }) {
    final TrackingServiceMock mock = TrackingServiceMock(simulate: simulate);

    // Only generate tracking for automatically generated incidents
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        final trackings = mock.trackingsRepo.putIfAbsent(iuuid, () => {});
        // Create unit tracking
        trackings.addEntries(
          _createTrackingUnits(
            iuuid,
            mock.s2t,
            unitCount,
          ),
        );

        // Create personnel tracking
        trackings.addEntries(
          _createTrackingPersonnel(
            iuuid,
            mock.s2t,
            personnelCount,
          ),
        );

        // Create simulations?
        if (simulate) {
          trackings.keys.forEach(
            (uuid) => _simulate(
              uuid,
              trackings,
              deviceServiceMock.deviceRepo[iuuid],
              mock.simulations,
            ),
          );
        }
        mock.trackingsRepo.putIfAbsent(iuuid, () => trackings);
      }
    });

    deviceServiceMock.messages.listen((message) => _handle(
          message,
          mock.s2t,
          mock.trackingsRepo,
          mock.simulations,
          mock.controller,
        ));

    when(mock.messages).thenAnswer(
      (_) => mock.controller.stream,
    );

    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var trackingList = mock.trackingsRepo[iuuid];
      if (trackingList == null) {
        trackingList = mock.trackingsRepo.putIfAbsent(iuuid, () => {});
      }

      return ServiceResponse.ok(body: trackingList.values.toList());
    });

    when(mock.create(any, any)).thenAnswer((_) async {
      final iuuid = _.positionalArguments[0] as String;
      final tracking = _.positionalArguments[1] as Tracking;
      return _create(
        iuuid: iuuid,
        s2t: mock.s2t,
        tracking: tracking,
        simulations: mock.simulations,
        trackingRepo: mock.trackingsRepo,
        deviceRepo: deviceServiceMock.deviceRepo,
        simulate: simulate,
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      var request = _.positionalArguments[0] as Tracking;
      // Assumes that a device is attached to a single incident only
      var incident = mock.trackingsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(request.uuid),
        orElse: () => null,
      );
      if (incident != null) {
        // Update tracking instance
        var trackingList = incident.value;

        // Tracking does exists?
        if (!trackingList.containsKey(request.uuid))
          return ServiceResponse.notFound(
            message: "Not found. Tracking ${request.uuid}",
          );
        final original = trackingList[request.uuid];

        // Ensure only valid statuses are persisted
        var tracking = request.cloneWith(
            status: _toStatus(
          request.status,
          request.sources?.isNotEmpty == true,
        ));

//        // Append position to history if manual and does not exist in track
//        if (tracking.position != null && !tracking.history.contains(tracking.position)) {
//          if (tracking.position?.source == PositionSource.manual) {
//            tracking = tracking.cloneWith(position: request.position, history: tracking.history..add(request.position));
//          } else {
//            return _toOnlyManualResponse(request.position);
//          }
//        }

        final sources = request.sources.where(
          ((source) => !original.sources.contains(source) && mock.s2t.containsKey(source)),
        );
        if (sources.isNotEmpty) {
          return ServiceResponse.badRequest<Tracking>(message: "Bad request: Sources $sources are tracked already");
        }

        // Update tracking list
        trackingList.update(
          tracking.uuid,
          (_) => tracking,
          ifAbsent: () => tracking,
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
            trackingList,
            deviceServiceMock.deviceRepo[incident.key],
            mock.simulations,
          );
        }

        return ServiceResponse.ok(body: tracking);
      }
      return ServiceResponse.notFound(message: "Not found: Tracking ${request.uuid}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      // Assumes that a device is attached to a single incident only
      var incident = mock.trackingsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(tracking.uuid),
        orElse: () => null,
      );
      if (incident != null) {
        var trackingList = incident.value;
        trackingList.remove(tracking.uuid);
        mock.simulations.remove(tracking.uuid);
        mock.s2t.removeWhere((suuid, tuuid) => tuuid == tracking.uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.uuid}");
    });
    return mock;
  }

  static ServiceResponse<Tracking> _create({
    String iuuid,
    Tracking tracking,
    Map<String, String> s2t,
    Map<String, Map<String, Device>> deviceRepo,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
    bool simulate = false,
  }) {
//    final position = tracking.position;
    final sources = tracking.sources;
    final tuuid = tracking.uuid;

    // Sanity checks
    final found = sources.where(((source) => s2t.containsKey(source.uuid)));
    if (found.isNotEmpty) {
      return ServiceResponse.badRequest<Tracking>(
        message: "Bad request: Sources $found are tracked already",
      );
    }
//    if (position?.type != null && position?.source != PositionSource.manual) {
//      return _toOnlyManualResponse(position);
//    }

    final trackingList = trackingRepo[iuuid];
    trackingList.putIfAbsent(tuuid, () => tracking);
    final next = simulate
        ? _simulate(
            tuuid,
            trackingList,
            deviceRepo[iuuid],
            simulations,
          )
        : tracking;
    trackingList.putIfAbsent(tuuid, () => next);
    s2t.addEntries(
      next.sources.map((source) => MapEntry(source.uuid, tuuid)),
    );
    return ServiceResponse.ok<Tracking>(body: next);
  }

//  static ServiceResponse<Tracking> _toOnlyManualResponse(Position position) {
//    return ServiceResponse.badRequest(
//      message: "Bad request: "
//          "Only position of type 'Manual' is allowed, "
//          "found ${enumName(position?.type)}",
//    );
//  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingPersonnel(
    String iuuid,
    Map<String, String> s2t, // suuid -> tuuid
    int count,
  ) {
    // Track devices from app-series (tracking iuuid:t:p:$i -> device iuuid:d:a:$i)
    final tracking = _createTracking(iuuid, 'p', 'd:a', count);
    // Map device iuuid:d:a:$i -> tracking iuuid:t:p:$i
    _addEntries(iuuid, 'd:a', s2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingUnits(
    String iuuid,
    Map<String, String> s2t, // suuid -> tuuid
    int unitCount,
  ) {
    // Track devices from tetra-series (tracking iuuid:t:u:$i -> device iuuid:d:t:$i)
    final tracking = _createTracking(iuuid, 'u', 'd:t', unitCount);
    // Map device iuuid:d:t:$i -> tracking iuuid:t:u:$i
    _addEntries(iuuid, 'd:t', s2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTracking<T>(
    String iuuid,
    String entity,
    String device,
    int count,
  ) {
    return [
      for (var i = 1; i <= count; i++)
        Tracking.fromJson(
          TrackingBuilder.createAsJson(
            "$iuuid:t:$entity:$i",
            status: TrackingStatus.tracking,
          ),
        ).cloneWith(
            sources: List.from([
          Source(
            uuid: "$iuuid:$device:$i",
            type: SourceType.device,
          )
        ])),
    ].map((tracking) => MapEntry(tracking.uuid, tracking));
  }

  static void _addEntries(
    String iuuid,
    String type,
    Map<String, String> tracked,
    Iterable<MapEntry<String, Tracking>> items,
  ) {
    int i = 0;
    tracked.addEntries(
      items.map((entry) => MapEntry("$iuuid:$type:${++i}", entry.key)),
    );
  }

  static TrackingStatus _toStatus(TrackingStatus status, bool hasSources) {
    return [TrackingStatus.none, TrackingStatus.created].contains(status)
        ? (hasSources ? TrackingStatus.tracking : TrackingStatus.created)
        : (hasSources ? TrackingStatus.tracking : (TrackingStatus.closed == status ? status : TrackingStatus.paused));
  }

  static Tracking _simulate(
    String uuid,
    Map<String, Tracking> trackingList,
    Map<String, Device> devices,
    Map<String, _TrackSimulation> simulations,
  ) {
    var tracking = trackingList[uuid];
    if (tracking != null) {
      // Only simulate aggregated position for tracking with devices
      if ([
        TrackingStatus.created,
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
    Map<String, String> s2t,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
    StreamController<TrackingMessage> controller,
  ) {
    final device = Device.fromJson(message.json);
    if (s2t.containsKey(device.uuid)) {
      final tuuid = s2t[device.uuid];
      // Assumes that a device is attached to a single incident only
      final incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(tuuid),
        orElse: () => null,
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
    String iuuid,
    String tuuid,
    Map<String, String> s2t,
    Map<String, _TrackSimulation> simulations,
    Map<String, Map<String, Tracking>> trackingRepo,
    StreamController<TrackingMessage> controller,
  ) {
    // Calculate
    final simulation = simulations[tuuid];
    if (simulation != null) {
      // Update aggregates first
      final auuids = _toAggregateIds(device.uuid, tuuid, trackingRepo[iuuid], s2t)
        ..forEach(
          (auuid) => _progress(
            device,
            iuuid,
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
      final trackingList = trackingRepo[iuuid];
      final next = simulation.progress(
        suuids: [...auuids, device.uuid],
      );
      trackingList[tuuid] = next;
      trackingRepo.update(iuuid, (_) => trackingList);

      // Notify listeners
      controller.add(
        TrackingMessage(
          next.uuid,
          TrackingMessageType.updated,
          next.toJson(),
        ),
      );
    }
  }

  static List<String> _toAggregateIds(
    String suuid,
    String tuuid,
    Map<String, Tracking> trackingList,
    Map<String, String> s2t,
  ) =>
      s2t.entries
          .where((e) => tuuid == e.key)
          .where(
            (e) => trackingList[e.key]
                ?.sources
                // Only match aggregates
                ?.any((source) => SourceType.trackable == source.type && source.uuid == suuid),
          )
          .map((e) => e.value)
          .toList();
}

class _TrackSimulation {
  final String uuid;
  final Map<String, Device> devices;
  final Map<String, Tracking> trackingList;

  Tracking get tracking => trackingList[uuid];

  _TrackSimulation({
    @required this.uuid,
    @required this.trackingList,
    @required this.devices,
  });

  Tracking progress({
    Iterable<String> suuids = const [],
  }) {
    final current = tracking;
    if (current.status == TrackingStatus.tracking) {
      Position position;
      double distance;
      double speed;
      Duration effort;

      final sources = current?.sources ?? [];

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
          timestamp: DateTime.fromMillisecondsSinceEpoch(sum[3]),
          acc: sum[2] / sources.length,
        );
      }

      // Only add updated positions to tracks
      final updated = sources.where((source) => suuids.contains(source.uuid));
      final tracks = current.tracks.where((track) => updated.contains(track.source))
        ..map((track) {
          final positions = track.positions.toList();
          final position = _toPosition(track.source);
          if (!positions.contains(position)) {
            return track.cloneWith(
              positions: positions..add(position),
            );
          }
          return track;
        });

      // Only add position if not added already
      List<Position> history = current.history.contains(position) ? current.history : [...current.history, position];

      // Limit history and tracks to maximum 10 items each (prevent unbounded memory usage in long-running app)
      history = history.skip(max(0, history.length - 10)).toList();

      // Calculate effort, distance and speed
      if (history.length > 1) {
        effort = TrackingUtils.effort(history);
        distance = current.distance == null ? distance : TrackingUtils.distance(history, distance: current.distance);
        speed = TrackingUtils.speed(distance, effort);
      }

      return current.cloneWith(
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

  Position _toPosition(Source source) =>
      SourceType.device == source.type ? _fromDevice(source.uuid) : _fromAggregate(source.uuid);

  Position _fromDevice(String uuid) => devices[uuid]?.position;
  Position _fromAggregate(String uuid) => trackingList[uuid]?.position;

  List<num> _aggregate(List<num> sum, Position position) => position == null
      ? sum
      : [
          position.lat + sum[0],
          position.lon + sum[1],
          (position.acc ?? 0.0) + sum[2],
          min(position.timestamp.millisecondsSinceEpoch, sum[3])
        ];
}
