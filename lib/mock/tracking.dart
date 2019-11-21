import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Track.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';

import 'devices.dart';

class TracksBuilder {
  static Map<String, dynamic> createTrackingAsJson(
    String id, {
    TrackingStatus status = TrackingStatus.Tracking,
  }) {
    return json.decode('{'
        '"id": "$id",'
        '"status": "${enumName(status)}",'
        '"distance": 0,'
        '"devices": [],'
        '"aggregates": [],'
        '"history": [],'
        '"tracks": {}'
        '}');
  }

  static double nextDouble(rnd, double fraction, {negative: true}) {
    return (negative ? (-100 + rnd.nextInt(200)).toDouble() : rnd.nextInt(100)) / 100 * fraction;
  }
}

class TrackingServiceMock extends Mock implements TrackingService {
  TrackingServiceMock();

  factory TrackingServiceMock.build(
    final IncidentBloc incidentBloc,
    final DeviceServiceMock deviceServiceMock,
    final personnelCount,
    final unitCount,
  ) {
    final Map<String, String> d2t = {}; // deviceId -> trackingId
    final Map<String, String> a2t = {}; // aggregate trackingId -> trackingId
    final Map<String, _TrackSimulation> simulations = {}; // trackingId -> simulation
    final Map<String, Map<String, Tracking>> trackingRepo = {}; // incidentId -> trackingId -> tracking

    final StreamController<TrackingMessage> controller = StreamController.broadcast();

    deviceServiceMock.messages.listen((message) => _handle(
          message,
          d2t,
          a2t,
          trackingRepo,
          simulations,
          controller,
        ));

    final mock = TrackingServiceMock();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.fetch(any)).thenAnswer((_) async {
      final String incidentId = _.positionalArguments[0];
      var trackingList = trackingRepo[incidentId];
      if (trackingList == null) {
        trackingList = trackingRepo.putIfAbsent(incidentId, () => {});
      }
      // Only generate tracking for automatically generated incidents
      if (incidentId.startsWith('a:') && trackingList.isEmpty) {
        // Create unit tracking
        trackingList.addEntries(
          _createTrackingUnits(
            incidentId,
            d2t,
            unitCount,
          ),
        );

        // Create personnel tracking
        trackingList.addEntries(
          _createTrackingPersonnel(
            incidentId,
            d2t,
            personnelCount,
          ),
        );

        // Create simulations
        trackingList.keys.forEach(
          (id) => _simulate(
            id,
            trackingList,
            deviceServiceMock.deviceRepo[incidentId],
            simulations,
          ),
        );
      }
      trackingRepo.putIfAbsent(incidentId, () => trackingList);
      return ServiceResponse.ok(body: trackingList.values.toList());
    });

    when(mock.create(
      any,
      point: anyNamed("point"),
      devices: anyNamed("devices"),
      aggregates: anyNamed("aggregates"),
    )).thenAnswer((_) async {
      final incidentId = _.positionalArguments[0];
      return _create(
        incidentId: incidentId,
        d2t: d2t,
        a2t: a2t,
        point: _.namedArguments[Symbol("point")] as Point,
        devices: _.namedArguments[Symbol("devices")] as List<String> ?? <String>[],
        aggregates: _.namedArguments[Symbol("aggregates")] as List<String> ?? <String>[],
        simulations: simulations,
        trackingRepo: trackingRepo,
        deviceRepo: deviceServiceMock.deviceRepo,
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      var request = _.positionalArguments[0] as Tracking;
      // Assumes that a device is attached to a single incident only
      var incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(request.id),
        orElse: () => null,
      );
      if (incident != null) {
        // Update tracking instance
        var trackingList = incident.value;

        // Tracking does exists?
        if (!trackingList.containsKey(request.id))
          return ServiceResponse.notFound(
            message: "Not found. Tracking ${request.id}",
          );
        final original = trackingList[request.id];

        // Ensure only valid statuses are persisted
        var tracking = request.cloneWith(
            status: _toStatus(
          request.status,
          request.devices.isNotEmpty,
          request.aggregates.isNotEmpty,
        ));

        // Append position to history if manual and does not exist in track
        if (tracking.point != null && !tracking.history.contains(tracking.point)) {
          if (tracking.point?.type == PointType.Manual) {
            tracking = tracking.cloneWith(point: request.point, history: tracking.history..add(request.point));
          } else {
            return _toOnlyManualResponse(request.point);
          }
        }

        final dd = request.devices.where(((id) => !original.devices.contains(id) && d2t.containsKey(id)));
        if (dd.isNotEmpty) {
          return ServiceResponse.badRequest<Tracking>(message: "Bad request, devices $dd are tracked already");
        }

        final dt = request.aggregates.where(((id) => !original.aggregates.contains(id) && d2t.containsKey(id)));
        if (dt.isNotEmpty) {
          return ServiceResponse.badRequest<Tracking>(message: "Bad request, aggregates $dt are tracked already");
        }

        // Update tracking list
        trackingList.update(
          tracking.id,
          (_) => tracking,
          ifAbsent: () => tracking,
        );

        // Remove all and add again
        d2t.removeWhere((_, trackingId) => trackingId == tracking.id);
        d2t.addEntries(
          tracking.devices.map((deviceId) => MapEntry(deviceId, tracking.id)),
        );

        // Remove all and add again
        a2t.removeWhere((_, trackingId) => trackingId == tracking.id);
        a2t.addEntries(
          tracking.aggregates.map((trackingId) => MapEntry(trackingId, tracking.id)),
        );

        // Configure simulation
        _simulate(
          tracking.id,
          trackingList,
          deviceServiceMock.deviceRepo[incident.key],
          simulations,
        );

        return ServiceResponse.ok(body: tracking);
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${request.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      // Assumes that a device is attached to a single incident only
      var incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(tracking.id),
        orElse: () => null,
      );
      if (incident != null) {
        var trackingList = incident.value;
        trackingList.remove(tracking.id);
        simulations.remove(tracking.id);
        d2t.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    return mock;
  }

  static ServiceResponse<Tracking> _create({
    String incidentId,
    Point point,
    List<String> devices = const [],
    List<String> aggregates = const [],
    Map<String, String> d2t,
    Map<String, String> a2t,
    Map<String, Map<String, Device>> deviceRepo,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
  }) {
    // Sanity checks
    final dd = devices.where(((id) => d2t.containsKey(id)));
    if (dd.isNotEmpty) {
      return ServiceResponse.badRequest<Tracking>(message: "Bad request, devices $dd are tracked already");
    }
    final td = aggregates.where(((id) => a2t.containsKey(id)));
    if (td.isNotEmpty) {
      return ServiceResponse.badRequest<Tracking>(message: "Bad request, aggregates $td are tracked already");
    }
    if (point?.type != null && point?.type != PointType.Manual) {
      return _toOnlyManualResponse(point);
    }

    final trackingList = trackingRepo[incidentId];
    final trackingId = "$incidentId:t:${randomAlphaNumeric(8).toLowerCase()}";
    var tracking = Tracking.fromJson(TracksBuilder.createTrackingAsJson(
      trackingId,
      status: _toStatus(TrackingStatus.Tracking, devices.isNotEmpty, aggregates.isNotEmpty),
    )).cloneWith(
      point: point,
      devices: devices,
      aggregates: aggregates,
    );
    trackingList.putIfAbsent(trackingId, () => tracking);
    tracking = _simulate(
      trackingId,
      trackingList,
      deviceRepo[incidentId],
      simulations,
    );
    trackingList.putIfAbsent(trackingId, () => tracking);
    d2t.addEntries(
      tracking.devices.map((deviceId) => MapEntry(deviceId, trackingId)),
    );
    a2t.addEntries(
      tracking.aggregates.map((aggregateId) => MapEntry(aggregateId, trackingId)),
    );
    return ServiceResponse.ok<Tracking>(body: tracking);
  }

  static ServiceResponse<Tracking> _toOnlyManualResponse(Point point) {
    return ServiceResponse.badRequest(
      message: "Bad request. "
          "Only point of type 'Manual' is allowed, "
          "found ${enumName(point?.type)}",
    );
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingPersonnel(
    String incidentId,
    Map<String, String> d2t, // deviceId -> trackingId
    int count,
  ) {
    // Track devices from app-series (tracking incidentId:t:p:$i -> device incidentId:d:a:$i)
    final tracking = _createTracking(incidentId, 'p', 'd:a', count);
    // Map device incidentId:d:a:$i -> tracking incidentId:t:p:$i
    _addEntries(incidentId, 'd:a', d2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingUnits(
    String incidentId,
    Map<String, String> d2t, // deviceId -> trackingId
    int unitCount,
  ) {
    // Track devices from tetra-series (tracking incidentId:t:u:$i -> device incidentId:d:t:$i)
    final tracking = _createTracking(incidentId, 'u', 'd:t', unitCount);
    // Map device incidentId:d:t:$i -> tracking incidentId:t:u:$i
    _addEntries(incidentId, 'd:t', d2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTracking<T>(
    String incidentId,
    String entity,
    String device,
    int count,
  ) {
    return [
      for (var i = 1; i <= count; i++)
        Tracking.fromJson(
          TracksBuilder.createTrackingAsJson(
            "$incidentId:t:$entity:$i",
            status: TrackingStatus.Tracking,
          ),
        ).cloneWith(devices: List.from(["$incidentId:$device:$i"])),
    ].map((tracking) => MapEntry(tracking.id, tracking));
  }

  static void _addEntries(
    String incidentId,
    String type,
    Map<String, String> tracked,
    Iterable<MapEntry<String, Tracking>> items,
  ) {
    int i = 0;
    tracked.addEntries(
      items.map((entry) => MapEntry("$incidentId:$type:${++i}", entry.key)),
    );
  }

  static TrackingStatus _toStatus(TrackingStatus status, bool hasDevices, bool hasAggregates) {
    return [TrackingStatus.None, TrackingStatus.Created].contains(status)
        ? (hasDevices || hasAggregates ? TrackingStatus.Tracking : TrackingStatus.Created)
        : (hasDevices || hasAggregates
            ? TrackingStatus.Tracking
            : (TrackingStatus.Closed == status ? status : TrackingStatus.Paused));
  }

  static Tracking _simulate(
    String id,
    Map<String, Tracking> trackingList,
    Map<String, Device> devices,
    Map<String, _TrackSimulation> simulations,
  ) {
    var tracking = trackingList[id];
    if (tracking != null) {
      // Only simulate aggregated position for tracking with devices
      if ([
        TrackingStatus.Created,
        TrackingStatus.Tracking,
        TrackingStatus.Paused,
      ].contains(tracking.status)) {
        final simulation = _TrackSimulation(
          id: id,
          trackingList: trackingList,
          devices: devices,
        );
        tracking = simulation.progress();
        simulations.update(id, (_) => simulation, ifAbsent: () => simulation);
      } else {
        simulations.remove(id);
      }
    }
    return tracking;
  }

  static void _handle(
    DeviceMessage message,
    Map<String, String> d2t,
    Map<String, String> a2t,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
    StreamController<TrackingMessage> controller,
  ) {
    final device = Device.fromJson(message.json);
    if (d2t.containsKey(device.id)) {
      final trackingId = d2t[device.id];
      // Assumes that a device is attached to a single incident only
      final incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(trackingId),
        orElse: () => null,
      );
      if (incident != null) {
        // 2) Append new position to track, calculate new position, update and notify
        _progress(
          device,
          incident.key,
          trackingId,
          a2t,
          simulations,
          trackingRepo,
          controller,
        );
      }
    }
  }

  static void _progress(
    Device device,
    String incidentId,
    String trackingId,
    Map<String, String> a2t,
    Map<String, _TrackSimulation> simulations,
    Map<String, Map<String, Tracking>> trackingRepo,
    StreamController<TrackingMessage> controller,
  ) {
    // Calculate
    final simulation = simulations[trackingId];
    if (simulation != null) {
      // Update aggregates first
      final aggregateIds = _toAggregateIds(device.id, trackingId, trackingRepo[incidentId], a2t)
        ..forEach(
          (aggregateId) => _progress(
            device,
            incidentId,
            aggregateId,
            a2t,
            simulations,
            trackingRepo,
            controller,
          ),
        );

      // Update device position
      simulation.devices[device.id] = device;

      // Append to track, calculate next position, effort and speed
      final trackingList = trackingRepo[incidentId];
      final next = simulation.progress(
        deviceIds: [device.id],
        aggregateIds: aggregateIds,
      );
      trackingList[trackingId] = next;
      trackingRepo.update(incidentId, (_) => trackingList);

      // Notify listeners
      controller.add(TrackingMessage(incidentId, TrackingMessageType.TrackingChanged, next.toJson()));
    }
  }

  static List<String> _toAggregateIds(
    String deviceId,
    String trackingId,
    Map<String, Tracking> trackingList,
    Map<String, String> a2t,
  ) =>
      a2t.entries
          .where((e) => trackingId == e.key)
          .where((e) => trackingList[e.key]?.devices?.contains(deviceId) == true)
          .map((e) => e.value)
          .toList();
}

class _TrackSimulation {
  final String id;
  final Map<String, Device> devices;
  final Map<String, Tracking> trackingList;

  Tracking get tracking => trackingList[id];

  _TrackSimulation({
    @required this.id,
    @required this.trackingList,
    @required this.devices,
  });

  Tracking progress({
    Iterable<String> deviceIds = const [],
    Iterable<String> aggregateIds = const [],
  }) {
    Point point;
    double distance;
    double speed;
    Duration effort;

    final devices = tracking?.devices ?? [];
    final aggregates = tracking?.aggregates ?? [];

    // Not tracking?
    if (devices.isEmpty && aggregates.isEmpty)
      point = tracking.point;
    // Tracking devices only?
    else if (devices.isNotEmpty && aggregates.isEmpty)
      point = _fromDevice(tracking.devices.first) ?? tracking.point;
    // Tracking aggregates only?
    else if (devices.isEmpty && aggregates.isNotEmpty)
      point = _fromAggregate(aggregates.first) ?? tracking.point;
    else {
      // Calculate geometric centre of all devices and personnel as the arithmetic mean of the input coordinates
      var sum = [0.0, 0.0, 0.0, DateTime.now().millisecondsSinceEpoch].toList();
      sum = devices.fold<List<num>>(sum, (sum, next) => _aggregate(sum, _fromDevice(next)));
      sum = aggregates.fold<List<num>>(sum, (sum, next) => _aggregate(sum, _fromAggregate(next)));
      final count = (devices.length + aggregates.length);
      point = Point(
        type: PointType.Aggregated,
        lat: sum[0] / count,
        lon: sum[1] / count,
        acc: sum[2] / count,
        timestamp: DateTime.fromMillisecondsSinceEpoch(sum[3]),
      );
    }

    // Only add to device track and tracking history if status is Tracking
    List<Point> history;
    if (tracking.status == TrackingStatus.Tracking) {
      _update(deviceIds, TrackType.Device, (id) => _fromDevice(id));
      _update(aggregateIds, TrackType.Aggregate, (id) => _fromAggregate(id));
      // Only add point if not added already
      history = tracking.history.contains(point)
          ? tracking.history
          : List.of(
              tracking.history,
              growable: true,
            )
        ..add(point);
    } else {
      history = tracking.history;
    }

    // Limit history and tracks to maximum 10 items each (prevent unbounded memory usage in long-running app)
    history = history.skip(max(0, history.length - 10)).toList();
    final tracks = tracking.tracks.map(
      (id, track) => MapEntry(id, track.truncate(10)),
    );

    // Calculate effort, distance and speed
    if (history.length > 1) {
      effort = asEffort(history);
      distance = (tracking.distance == null ? distance : asDistance(history, distance: tracking.distance));
      speed = asSpeed(distance, effort);
    }

    return tracking.cloneWith(
      point: point,
      distance: distance ?? 0.0,
      speed: speed ?? 0.0,
      effort: effort ?? Duration.zero,
      history: history,
      tracks: tracks,
    );
  }

  void _update(Iterable<String> ids, TrackType type, Point toPoint(String id)) {
    return ids.forEach(
      (id) => tracking.tracks.update(
        id,
        // Only add point if not added already
        (Track track) => track.points.contains(toPoint(id))
            ? track
            : Track(
                points: track.points..add(toPoint(id)),
                type: type,
              ),
        ifAbsent: () => Track(points: [toPoint(id)], type: TrackType.Device),
      ),
    );
  }

  Point _fromDevice(String id) => devices[id]?.point;
  Point _fromAggregate(String id) => trackingList[id]?.point;

  List<num> _aggregate(List<num> sum, Point point) => point == null
      ? sum
      : [
          point.lat + sum[0],
          point.lon + sum[1],
          (point.acc ?? 0.0) + sum[2],
          min(point.timestamp.millisecondsSinceEpoch, sum[3])
        ];
}
