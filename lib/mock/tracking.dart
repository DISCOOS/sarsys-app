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

import 'devices.dart';

class TracksBuilder {
  static Map<String, dynamic> createTrackingAsJson(
    String id, {
    List<String> devices = const [],
    TrackingStatus status = TrackingStatus.Tracking,
  }) {
    return json.decode('{'
        '"id": "$id",'
        '"status": "${enumName(status)}",'
        '"distance": 0,'
        '"devices": ["${devices.join(",")}"]'
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
      var tracks = trackingRepo[incidentId];
      if (tracks == null) {
        tracks = trackingRepo.putIfAbsent(incidentId, () => {});
      }
      if (tracks.isEmpty) {
        // Create tracks
        tracks.addEntries([
          for (var i = 1; i <= count; i++)
            Tracking.fromJson(
              TracksBuilder.createTrackingAsJson(
                "${incidentId}t$i",
                devices: List.from(["${incidentId}d$i"]),
              ),
            ),
        ].map((tracking) => MapEntry(tracking.id, tracking)));
        // Create simulations
        tracks.keys.forEach(
          (id) => _simulate(id, tracks, deviceServiceMock.deviceRepo[incidentId], simulations),
        );
        var i = 0;
        trackedUnits.addEntries(
          tracks.map((trackingId, tracking) => MapEntry("${incidentId}u${++i}", trackingId)).entries,
        );
        i = 0;
        trackedDevices.addEntries(
          tracks.map((trackingId, tracking) => MapEntry("${incidentId}d${++i}", trackingId)).entries,
        );
      }
      trackingRepo.putIfAbsent(incidentId, () => tracks);
      return ServiceResponse.ok(body: tracks.values.toList());
    });
    when(mock.create(any, any)).thenAnswer((_) async {
      var unitId = _.positionalArguments[0];
      if (trackedUnits.containsKey(unitId)) {
        return ServiceResponse.noContent();
      }
      var devices = _.positionalArguments[1];
      final incident = unitServiceMock.unitsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(unitId),
        orElse: null,
      );
      if (incident == null) {
        return ServiceResponse.notFound(message: "Not found. Unit $unitId.");
      }
      final tracks = trackingRepo[incident.key];
      final trackingId = "${incident.key}t${tracks.length + 1}";
      final tracking = Tracking.fromJson(TracksBuilder.createTrackingAsJson(
        trackingId,
        devices: devices,
      ));
      _simulate(trackingId, tracks, deviceServiceMock.deviceRepo[incident.key], simulations);
      tracks.putIfAbsent(tracking.id, () => tracking);
      trackedUnits.putIfAbsent(unitId, () => tracking.id);
      trackedDevices.addEntries(
        tracking.devices.map((deviceId) => MapEntry(deviceId, trackingId)),
      );
      return ServiceResponse.ok(body: tracks.putIfAbsent(tracking.id, () => tracking));
    });
    when(mock.update(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      var incident = trackingRepo.entries.firstWhere((entry) => entry.value.containsKey(tracking.id), orElse: null);
      if (incident != null) {
        var tracks = incident.value;
        tracks.update(
          tracking.id,
          (_) => tracking,
          ifAbsent: () => tracking,
        );

        // Remove all and add again
        trackedDevices.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        trackedDevices.addEntries(
          tracking.devices.map((deviceId) => MapEntry(deviceId, tracking.id)),
        );

        // Configure simulation
        _simulate(tracking.id, tracks, deviceServiceMock.deviceRepo[incident.key], simulations);

        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var tracking = _.positionalArguments[0];
      var incident = trackingRepo.entries.firstWhere((entry) => entry.value.containsKey(tracking.id), orElse: null);
      if (incident != null) {
        var tracks = incident.value;
        tracks.remove(tracking.id);
        simulations.remove(tracking.id);
        trackedUnits.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        trackedDevices.removeWhere((deviceId, trackingId) => trackingId == tracking.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Tracking ${tracking.id}");
    });
    return mock;
  }

  static Tracking _simulate(
    String id,
    Map<String, Tracking> tracks,
    Map<String, Device> devices,
    Map<String, _TrackSimulation> simulations,
  ) {
    var tracking;
    if (TrackingStatus.Tracking == tracks[id].status) {
      final simulation = _TrackSimulation(
        id: id,
        tracks: tracks,
        devices: devices,
      );
      tracking = simulation.progress();
      simulations.update(id, (_) => simulation, ifAbsent: () => simulation);
    } else {
      tracking = simulations.remove(id).tracking;
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
          // Calculate new position, update and notfiy
          final next = simulation.progress();
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
  final Map<String, Tracking> tracks;

  Tracking get tracking => tracks[id];

  _TrackSimulation({this.id, this.tracks, this.devices = const {}});

  Tracking progress() {
    var location;
    if (tracking.devices.isEmpty)
      location = tracking.location;
    else if (tracking.devices.length == 1)
      location = devices[tracking.devices.first]?.location ?? tracking.location;
    else {
      // Calculate geometric centre of all devices as the arithmetic mean of the input coordinates
      final sum = tracking.devices.fold<List<double>>(
        [0.0, 0.0, 0.0].toList(),
        (previous, next) => devices[next] == null
            ? previous
            : [
                devices[next].location.lat + previous[0],
                devices[next].location.lon + previous[1],
                devices[next].location.acc + previous[2],
              ],
      );
      location = Point.now(
        sum[0] / tracking.devices.length,
        sum[1] / tracking.devices.length,
        acc: sum[2] / tracking.devices.length,
      );
    }
    final track = List.of(tracking.track == null ? <Point>[] : tracking.track, growable: true)..add(location);
    return tracking.cloneWith(
      location: location,
      track: track.skip(max(0, track.length - 10)).toList(),
    );
  }
}
