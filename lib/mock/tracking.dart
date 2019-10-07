import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/blocs/incident_bloc.dart';
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

  static String createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }

  static String createRandomPointAsJson(rnd, Point center) {
    return TracksBuilder.createPointAsJson(center.lat + nextDouble(rnd, 0.03), center.lon + nextDouble(rnd, 0.03));
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
    final DeviceServiceMock deviceServiceMock,
    final count,
  ) {
    final Map<String, String> trackedUnits = {}; // unitId -> trackingId
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
      var incidentId = _.positionalArguments[0];
      var trackingList = trackingRepo[incidentId];
      if (trackingList == null) {
        trackingList = trackingRepo.putIfAbsent(incidentId, () => {});
      }
      if (trackingList.isEmpty) {
        // Create trackingList
        trackingList.addEntries([
          for (var i = 1; i <= count; i++)
            Tracking.fromJson(
              TracksBuilder.createTrackingAsJson(
                "$incidentId:t:$i",
                status: TrackingStatus.Tracking,
              ),
            ).cloneWith(devices: List.from(["${incidentId}d$i"])),
        ].map((tracking) => MapEntry(tracking.id, tracking)));
        // Create simulations
        trackingList.keys.forEach(
          (id) => _simulate(id, trackingList, deviceServiceMock.deviceRepo[incidentId], simulations),
        );
        var i = 0;
        trackedUnits.addEntries(
          trackingList.map((trackingId, tracking) => MapEntry("${incidentId}u${++i}", trackingId)).entries,
        );
        i = 0;
        trackedDevices.addEntries(
          trackingList.map((trackingId, tracking) => MapEntry("${incidentId}d${++i}", trackingId)).entries,
        );
      }
      trackingRepo.putIfAbsent(incidentId, () => trackingList);
      return ServiceResponse.ok(body: trackingList.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var unitId = _.positionalArguments[0];
      if (trackedUnits.containsKey(unitId)) {
        return ServiceResponse.noContent();
      }
      var devices = _.positionalArguments[1] as List<String>;
      final incident = unitServiceMock.unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(unitId),
        orElse: () => null,
      );
      if (incident == null) {
        return ServiceResponse.notFound(message: "Not found. Unit $unitId.");
      }
      final trackingList = trackingRepo[incident.key];
      final trackingId = "${incident.key}:t:${randomAlphaNumeric(8).toLowerCase()}";
      var tracking = Tracking.fromJson(TracksBuilder.createTrackingAsJson(
        trackingId,
        status: _toStatus(TrackingStatus.Tracking, devices.isNotEmpty),
      )).cloneWith(devices: devices);
      trackingList.putIfAbsent(tracking.id, () => tracking);
      tracking = _simulate(
        trackingId,
        trackingList,
        deviceServiceMock.deviceRepo[incident.key],
        simulations,
      );
      trackingList.putIfAbsent(tracking.id, () => tracking);
      trackedUnits.putIfAbsent(unitId, () => tracking.id);
      trackedDevices.addEntries(
        tracking.devices.map((deviceId) => MapEntry(deviceId, trackingId)),
      );
      return ServiceResponse.ok(body: tracking);
    });
    when(mock.update(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0] as Tracking;
      var incident = trackingRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(tracking.id),
        orElse: () => null,
      );
      if (incident != null) {
        // Ensure only valid statuses are persisted
        tracking = tracking.cloneWith(status: _toStatus(tracking.status, tracking.devices.isNotEmpty));
        // Update trackings
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

        return ServiceResponse.ok(body: tracking.status);
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
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
        trackedUnits.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        trackedDevices.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    return mock;
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
    Point location;
    double distance;
    double speed;
    Duration effort;

    if (tracking.devices.isEmpty)
      location = tracking.location;
    else if (tracking.devices.length == 1)
      location = devices[tracking.devices.first]?.location ?? tracking.location;
    else {
      // Calculate geometric centre of all devices as the arithmetic mean of the input coordinates
      final sum = tracking.devices.fold<List<num>>(
        [0.0, 0.0, 0.0, DateTime.now().millisecondsSinceEpoch].toList(),
        (previous, next) => devices[next] == null
            ? previous
            : [
                devices[next].location.lat + previous[0],
                devices[next].location.lon + previous[1],
                devices[next].location.acc + previous[2],
                min(devices[next].location.timestamp.millisecondsSinceEpoch, previous[3])
              ],
      );
      location = Point(
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
          (track) => track..add(devices[id].location),
          ifAbsent: () => [devices[id].location],
        ),
      );
      history = List.of(
        tracking.history,
        growable: true,
      )..add(location);
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
        location: location,
        distance: distance ?? 0.0,
        speed: speed ?? 0.0,
        effort: effort ?? Duration.zero,
        history: history.skip(max(0, history.length - 10)).toList(),
        tracks: tracking.tracks.map((id, track) => MapEntry(id, track.skip(max(0, track.length - 10)).toList())));
  }
}
