import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/mock/personnel.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
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
    final UnitServiceMock unitServiceMock,
    final PersonnelServiceMock personnelServiceMock,
    final DeviceServiceMock deviceServiceMock,
    final personnelCount,
    final unitCount,
  ) {
    final Map<String, String> u2t = {}; // unitId -> trackingId
    final Map<String, String> p2t = {}; // personnelId -> trackingId
    final Map<String, String> d2t = {}; // deviceId -> trackingId
    final Map<String, String> t2t = {}; // trackingId -> trackingId
    final Map<String, _TrackSimulation> simulations = {}; // trackingId -> simulation
    final Map<String, Map<String, Tracking>> trackingRepo = {}; // incidentId -> trackingId -> tracking

    final StreamController<TrackingMessage> controller = StreamController.broadcast();

    deviceServiceMock.messages.listen((message) => _handle(
          message,
          d2t,
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
            u2t,
            d2t,
            unitCount,
          ),
        );

        // Create personnel tracking
        trackingList.addEntries(
          _createTrackingPersonnel(
            incidentId,
            p2t,
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
            personnelServiceMock.personnelRepo[incidentId],
            simulations,
          ),
        );
      }
      trackingRepo.putIfAbsent(incidentId, () => trackingList);
      return ServiceResponse.ok(body: trackingList.values.toList());
    });

    when(mock.trackUnits(any, any, any)).thenAnswer((_) async {
      final unitId = _.positionalArguments[0];
      final incident = unitServiceMock.unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(unitId),
        orElse: () => null,
      );
      return _create(
        type: 'Unit',
        xId: unitId,
        incidentId: incident.key,
        x2t: u2t,
        d2t: d2t,
        t2t: t2t,
        devices: _.positionalArguments[1] as List<String>,
        aggregates: _.positionalArguments[2] as List<String>,
        simulations: simulations,
        trackingRepo: trackingRepo,
        deviceRepo: deviceServiceMock.deviceRepo,
        personnelRepo: personnelServiceMock.personnelRepo,
      );
    });

    when(mock.trackPersonnel(any, any)).thenAnswer((_) async {
      final personnelId = _.positionalArguments[0];
      final incident = personnelServiceMock.personnelRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnelId),
        orElse: () => null,
      );
      return _create(
        type: 'Personnel',
        xId: personnelId,
        incidentId: incident.key,
        x2t: p2t,
        d2t: d2t,
        t2t: t2t,
        devices: _.positionalArguments[1] as List<String>,
        simulations: simulations,
        deviceRepo: deviceServiceMock.deviceRepo,
        personnelRepo: personnelServiceMock.personnelRepo,
        trackingRepo: trackingRepo,
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      var original = _.positionalArguments[0] as Tracking;
      var incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(original.id),
        orElse: () => null,
      );
      if (incident != null) {
        // Ensure only valid statuses are persisted
        var tracking = original.cloneWith(
            status: _toStatus(
          original.status,
          original.devices.isNotEmpty,
          original.aggregates.isNotEmpty,
        ));

        // Append position to history if manual and does not exist in track
        if (!tracking.history.contains(original.point)) {
          if (tracking.point?.type == PointType.Manual) {
            tracking = tracking.cloneWith(point: original.point, history: tracking.history..add(original.point));
          } else {
            return ServiceResponse.badRequest(
              message: "Bad request. "
                  "Only point of type 'Manual' is allowed, "
                  "found ${enumName(original.point?.type)}",
            );
          }

          final dd = original.devices.where(((id) => d2t.containsKey(id)));
          if (dd.isNotEmpty) {
            return ServiceResponse.badRequest<Tracking>(message: "Bad request, devices $dd are tracked already");
          }

          final dt = original.aggregates.where(((id) => d2t.containsKey(id)));
          if (dt.isNotEmpty) {
            return ServiceResponse.badRequest<Tracking>(message: "Bad request, aggregates $dt are tracked already");
          }
        }
        // Update tracking instance
        var trackingList = incident.value;
        trackingList.update(
          tracking.id,
          (_) => tracking,
          ifAbsent: () => tracking,
        );

        // Remove all and add again
        d2t.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        d2t.addEntries(
          tracking.devices.map((deviceId) => MapEntry(deviceId, tracking.id)),
        );

        // Remove all and add again
        t2t.removeWhere((_, trackingId) => trackingId == tracking.id);
        t2t.addEntries(
          tracking.aggregates.map((trackingId) => MapEntry(trackingId, tracking.id)),
        );

        // Configure simulation
        _simulate(
          tracking.id,
          trackingList,
          deviceServiceMock.deviceRepo[incident.key],
          personnelServiceMock.personnelRepo[incident.key],
          simulations,
        );

        return ServiceResponse.ok(body: tracking);
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${original.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      var incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(tracking.id),
        orElse: () => null,
      );
      if (incident != null) {
        var trackingList = incident.value;
        trackingList.remove(tracking.id);
        simulations.remove(tracking.id);
        u2t.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        d2t.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    return mock;
  }

  static ServiceResponse<Tracking> _create({
    String type,
    String xId,
    String incidentId,
    List<String> devices,
    List<String> aggregates = const [],
    Map<String, String> x2t,
    Map<String, String> d2t,
    Map<String, String> t2t,
    Map<String, Map<String, Device>> deviceRepo,
    Map<String, Map<String, Personnel>> personnelRepo,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
  }) {
    if (x2t.containsKey(xId)) {
      return ServiceResponse.noContent<Tracking>();
    }

    if (incidentId == null) {
      return ServiceResponse.notFound<Tracking>(message: "Not found. $type $xId.");
    }

    final dd = devices.where(((id) => d2t.containsKey(id)));
    if (dd.isNotEmpty) {
      return ServiceResponse.badRequest<Tracking>(message: "Bad request, devices $dd are tracked already");
    }
    final td = aggregates.where(((id) => t2t.containsKey(id)));
    if (td.isNotEmpty) {
      return ServiceResponse.badRequest<Tracking>(message: "Bad request, aggregates $td are tracked already");
    }

    final prefix = type.toLowerCase().substring(0, 1);
    final trackingList = trackingRepo[incidentId];
    final trackingId = "$incidentId:t:$prefix:${randomAlphaNumeric(8).toLowerCase()}";
    var tracking = Tracking.fromJson(TracksBuilder.createTrackingAsJson(
      trackingId,
      status: _toStatus(TrackingStatus.Tracking, devices.isNotEmpty, aggregates.isNotEmpty),
    )).cloneWith(devices: devices);
    trackingList.putIfAbsent(trackingId, () => tracking);
    tracking = _simulate(
      trackingId,
      trackingList,
      deviceRepo[incidentId],
      personnelRepo[incidentId],
      simulations,
    );
    trackingList.putIfAbsent(trackingId, () => tracking);
    x2t.putIfAbsent(xId, () => trackingId);
    d2t.addEntries(
      tracking.devices.map((deviceId) => MapEntry(deviceId, trackingId)),
    );
    return ServiceResponse.ok<Tracking>(body: tracking);
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingPersonnel(
    String incidentId,
    Map<String, String> p2t, // personnelId -> trackingId
    Map<String, String> d2t, // deviceId -> trackingId
    int count,
  ) {
    // Track devices from app-series (tracking incidentId:t:p:$i -> device incidentId:d:a:$i)
    final tracking = _createTracking(incidentId, 'p', 'd:a', count);
    // Map personnel incidentId:p:$i -> tracking incidentId:t:p:$i
    _addEntries(incidentId, 'p', p2t, tracking);
    // Map device incidentId:d:a:$i -> tracking incidentId:t:p:$i
    _addEntries(incidentId, 'd:a', d2t, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingUnits(
    String incidentId,
    Map<String, String> u2t, // unitId -> trackingId
    Map<String, String> d2t, // deviceId -> trackingId
    int unitCount,
  ) {
    // Track devices from tetra-series (tracking incidentId:t:u:$i -> device incidentId:d:t:$i)
    final tracking = _createTracking(incidentId, 'u', 'd:t', unitCount);
    // Map personnel incidentId:u:$i -> tracking incidentId:t:u:$i
    _addEntries(incidentId, 'u', u2t, tracking);
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
    Map<String, Personnel> personnel,
    Map<String, _TrackSimulation> simulations,
  ) {
    var tracking = trackingList[id];
    if (tracking != null) {
      // Only simulate aggregated position for tracking with devices
      if (tracking.devices.isNotEmpty &&
          [
            TrackingStatus.Created,
            TrackingStatus.Tracking,
            TrackingStatus.Paused,
          ].contains(tracking.status)) {
        final simulation = _TrackSimulation(
          id: id,
          trackingList: trackingList,
          devices: devices,
          personnel: personnel,
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
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, _TrackSimulation> simulations,
    StreamController<TrackingMessage> controller,
  ) {
    final device = Device.fromJson(message.json);
    if (d2t.containsKey(device.id)) {
      final trackingId = d2t[device.id];
      final incident = trackingRepo.entries.firstWhere((entry) => entry.value.containsKey(trackingId));
      if (incident != null) {
        final simulation = simulations[trackingId];
        if (simulation != null) {
          simulation.devices[device.id] = device;
          // Append to tracks, calculate new position, update and notify
          final next = simulation.progress(
            deviceIds: [device.id],
          );
          trackingRepo[incident.key][trackingId] = next;
          controller.add(TrackingMessage(incident.key, TrackingMessageType.TrackingChanged, next.toJson()));
        }
      }
    }
  }
}

class _TrackSimulation {
  final String id;
  final Map<String, Device> devices;
  final Map<String, Personnel> personnel;
  final Map<String, Tracking> trackingList;

  Tracking get tracking => trackingList[id];

  _TrackSimulation({
    @required this.id,
    @required this.trackingList,
    @required this.devices,
    @required this.personnel,
  });

  Tracking progress({
    Iterable<String> deviceIds = const [],
    Iterable<String> personnelIds = const [],
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
    // Tracking personnel only?
    else if (devices.isEmpty && aggregates.isNotEmpty)
      point = _fromPersonnel(aggregates.first) ?? tracking.point;
    else {
      // Calculate geometric centre of all devices and personnel as the arithmetic mean of the input coordinates
      var sum = [0.0, 0.0, 0.0, DateTime.now().millisecondsSinceEpoch].toList();
      sum = devices.fold<List<num>>(sum, (sum, next) => _aggregate(sum, _fromDevice(next)));
      sum = aggregates.fold<List<num>>(sum, (sum, next) => _aggregate(sum, _fromPersonnel(next)));
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
      _update(deviceIds, (id) => _fromDevice(id));
      _update(personnelIds, (id) => _fromPersonnel(id));
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

  void _update(Iterable<String> ids, Point toPoint(String id)) {
    return ids.forEach(
      (id) => tracking.tracks.update(
        id,
        // Only add point if not added already
        (Track track) => track.points.contains(toPoint(id))
            ? track
            : Track(
                points: track.points..add(devices[id].point),
                type: TrackType.Device,
              ),
        ifAbsent: () => Track(points: [devices[id].point], type: TrackType.Device),
      ),
    );
  }

  Point _fromDevice(String id) => devices[id]?.point;
  Point _fromPersonnel(String id) => trackingList[personnel[id]?.tracking]?.point;

  List<num> _aggregate(List<num> sum, Point point) => point == null
      ? sum
      : [
          point.lat + sum[0],
          point.lon + sum[1],
          point.acc + sum[2],
          min(point.timestamp.millisecondsSinceEpoch, sum[3])
        ];
}
