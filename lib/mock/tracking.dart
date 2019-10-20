import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/mock/personnel.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/utils/data_utils.dart';
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
    final Map<String, String> units = {}; // unitId -> trackingId
    final Map<String, String> personnel = {}; // personnelId -> trackingId
    final Map<String, String> trackedDevices = {}; // deviceId -> trackingId
    final Map<String, _TrackSimulation> simulations = {}; // trackingId -> simulation
    final Map<String, Map<String, Tracking>> trackingRepo = {}; // incidentId -> trackingId -> tracking

    final StreamController<TrackingMessage> controller = StreamController.broadcast();

    deviceServiceMock.messages.listen((message) => _progress(
          message,
          trackingRepo,
          trackedDevices,
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
            units,
            trackedDevices,
            unitCount,
          ),
        );

        // Create personnel tracking
        trackingList.addEntries(
          _createTrackingPersonnel(
            incidentId,
            personnel,
            trackedDevices,
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

    when(mock.trackUnits(any, any)).thenAnswer((_) async {
      final unitId = _.positionalArguments[0];
      final incident = unitServiceMock.unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(unitId),
        orElse: () => null,
      );
      return _create(
        type: 'Unit',
        trackedId: unitId,
        incidentId: incident.key,
        devices: _.positionalArguments[1] as List<String>,
        tracked: units,
        trackingRepo: trackingRepo,
        deviceServiceMock: deviceServiceMock,
        simulations: simulations,
        trackedDevices: trackedDevices,
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
        trackedId: personnelId,
        incidentId: incident.key,
        devices: _.positionalArguments[1] as List<String>,
        tracked: units,
        trackingRepo: trackingRepo,
        deviceServiceMock: deviceServiceMock,
        simulations: simulations,
        trackedDevices: trackedDevices,
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
        var tracking = original.cloneWith(status: _toStatus(original.status, original.devices.isNotEmpty));

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
        }
        // Update tracking instance
        var trackingList = incident.value;
        trackingList.update(
          tracking.id,
          (_) => tracking,
          ifAbsent: () => tracking,
        );

        // Remove all and add again it device list is not empty
        trackedDevices.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        trackedDevices.addEntries(
          tracking.devices.map((deviceId) => MapEntry(deviceId, tracking.id)),
        );

        // Configure simulation
        _simulate(tracking.id, trackingList, deviceServiceMock.deviceRepo[incident.key], simulations);

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
        units.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        trackedDevices.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    return mock;
  }

  static ServiceResponse<Tracking> _create({
    String type,
    String trackedId,
    List<String> devices,
    String incidentId,
    Map<String, String> tracked,
    Map<String, Map<String, Tracking>> trackingRepo,
    DeviceServiceMock deviceServiceMock,
    Map<String, _TrackSimulation> simulations,
    Map<String, String> trackedDevices,
  }) {
    if (tracked.containsKey(trackedId)) {
      return ServiceResponse.noContent<Tracking>();
    }

    if (incidentId == null) {
      return ServiceResponse.notFound<Tracking>(message: "Not found. $type $trackedId.");
    }

    final prefix = type.toLowerCase().substring(0, 1);
    final trackingList = trackingRepo[incidentId];
    final trackingId = "$incidentId:t:$prefix:${randomAlphaNumeric(8).toLowerCase()}";
    var tracking = Tracking.fromJson(TracksBuilder.createTrackingAsJson(
      trackingId,
      status: _toStatus(TrackingStatus.Tracking, devices.isNotEmpty),
    )).cloneWith(devices: devices);
    trackingList.putIfAbsent(trackingId, () => tracking);
    tracking = _simulate(
      trackingId,
      trackingList,
      deviceServiceMock.deviceRepo[incidentId],
      simulations,
    );
    trackingList.putIfAbsent(trackingId, () => tracking);
    tracked.putIfAbsent(trackedId, () => trackingId);
    trackedDevices.addEntries(
      tracking.devices.map((deviceId) => MapEntry(deviceId, trackingId)),
    );
    return ServiceResponse.ok<Tracking>(body: tracking);
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingPersonnel(
    String incidentId,
    Map<String, String> personnel, // personnelId -> trackingId
    Map<String, String> trackedDevices, // deviceId -> trackingId
    int count,
  ) {
    // Track devices from app-series (tracking incidentId:t:p:$i -> device incidentId:d:a:$i)
    final tracking = _createTracking(incidentId, 'p', 'd:a', count);
    // Map personnel incidentId:p:$i -> tracking incidentId:t:p:$i
    _addEntries(incidentId, 'p', personnel, tracking);
    // Map device incidentId:d:a:$i -> tracking incidentId:t:p:$i
    _addEntries(incidentId, 'd:a', trackedDevices, tracking);
    return tracking;
  }

  static Iterable<MapEntry<String, Tracking>> _createTrackingUnits(
    String incidentId,
    Map<String, String> units, // unitId -> trackingId
    Map<String, String> trackedDevices, // deviceId -> trackingId
    int unitCount,
  ) {
    // Track devices from tetra-series (tracking incidentId:t:u:$i -> device incidentId:d:t:$i)
    final tracking = _createTracking(incidentId, 'u', 'd:t', unitCount);
    // Map personnel incidentId:u:$i -> tracking incidentId:t:u:$i
    _addEntries(incidentId, 'u', units, tracking);
    // Map device incidentId:d:t:$i -> tracking incidentId:t:u:$i
    _addEntries(incidentId, 'd:t', trackedDevices, tracking);
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

  static TrackingStatus _toStatus(TrackingStatus status, bool hasDevices) {
    return [TrackingStatus.None, TrackingStatus.Created].contains(status)
        ? (hasDevices ? TrackingStatus.Tracking : TrackingStatus.Created)
        : (hasDevices ? TrackingStatus.Tracking : (TrackingStatus.Closed == status ? status : TrackingStatus.Paused));
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
        );
        tracking = simulation.progress();
        simulations.update(id, (_) => simulation, ifAbsent: () => simulation);
      } else {
        simulations.remove(id);
      }
    }
    return tracking;
  }

  static void _progress(
    DeviceMessage message,
    Map<String, Map<String, Tracking>> trackingRepo,
    Map<String, String> trackedDevices,
    Map<String, _TrackSimulation> simulations,
    StreamController<TrackingMessage> controller,
  ) {
    final device = Device.fromJson(message.json);
    if (trackedDevices.containsKey(device.id)) {
      final trackingId = trackedDevices[device.id];
      final incident = trackingRepo.entries.firstWhere((entry) => entry.value.containsKey(trackingId));
      if (incident != null) {
        final simulation = simulations[trackingId];
        if (simulation != null) {
          simulation.devices[device.id] = device;
          // Append to tracks, calculate new position, update and notify
          final next = simulation.progress([device.id]);
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
  final Map<String, Tracking> trackingList;

  Tracking get tracking => trackingList[id];

  _TrackSimulation({this.id, this.trackingList, this.devices = const {}});

  Tracking progress([Iterable<String> ids = const []]) {
    Point point;
    double distance;
    double speed;
    Duration effort;

    if (tracking.devices.isEmpty)
      point = tracking.point;
    else if (tracking.devices.length == 1)
      point = devices[tracking.devices.first]?.point ?? tracking.point;
    else {
      // Calculate geometric centre of all devices as the arithmetic mean of the input coordinates
      final sum = tracking.devices.fold<List<num>>(
        [0.0, 0.0, 0.0, DateTime.now().millisecondsSinceEpoch].toList(),
        (previous, next) => devices[next] == null
            ? previous
            : [
                devices[next].point.lat + previous[0],
                devices[next].point.lon + previous[1],
                devices[next].point.acc + previous[2],
                min(devices[next].point.timestamp.millisecondsSinceEpoch, previous[3])
              ],
      );
      point = Point(
        type: PointType.Aggregated,
        lat: sum[0] / tracking.devices.length,
        lon: sum[1] / tracking.devices.length,
        acc: sum[2] / tracking.devices.length,
        timestamp: DateTime.fromMillisecondsSinceEpoch(sum[3]),
      );
    }

    // Only add to device track and tracking history if status is Tracking
    List<Point> history;
    if (tracking.status == TrackingStatus.Tracking) {
      ids.forEach(
        (id) => tracking.tracks.update(
          id,
          // Only add point if not added already
          (track) => track.contains(devices[id].point) ? track : track
            ..add(devices[id].point),
          ifAbsent: () => [devices[id].point],
        ),
      );
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

    // Calculate effort, distance and speed
    if (history.length > 1) {
      effort = asEffort(history);
      distance = (tracking.distance == null ? distance : asDistance(history, distance: tracking.distance));
      speed = asSpeed(distance, effort);
    }

    // Limit history and tracks to maximum 10 items each (prevent unbounded memory usage in long-running app)
    return tracking.cloneWith(
        point: point,
        distance: distance ?? 0.0,
        speed: speed ?? 0.0,
        effort: effort ?? Duration.zero,
        history: history.skip(max(0, history.length - 10)).toList(),
        tracks: tracking.tracks.map((id, track) => MapEntry(id, track.skip(max(0, track.length - 10)).toList())));
  }
}
