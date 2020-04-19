import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() async {
  final harness = BlocTestHarness()
    ..withIncidentBloc()
    ..install();

  test(
    'Incident bloc should be empty and unset',
    () async {
      expect(harness.incidentBloc.isEmpty, isTrue, reason: "Incident bloc should be empty");
      expect(harness.incidentBloc.isUnset, isTrue, reason: "Incident bloc should be unset");
      expect(harness.incidentBloc.initialState, isA<IncidentUnset>(), reason: "Unexpected incident state");
      _assertEvents(harness.incidentBloc, [
        emits(isA<IncidentUnset>()),
      ]);
    },
  );

  test('Incident bloc should contain two incidents', () async {
    List<Incident> incidents = await harness.incidentBloc.load();
    expect(incidents.length, 2, reason: "Bloc should return two incidents");
    expect(harness.incidentBloc.isEmpty, isFalse, reason: "Bloc should not be empty");
    expect(harness.incidentBloc.isUnset, isTrue, reason: "Bloc should not be in seleted state");
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentsCleared>()),
      emits(isA<IncidentsLoaded>()),
    ]);
  });

  test('Incident bloc should be in selected state', () async {
    List<Incident> incidents = await harness.incidentBloc.load();
    await harness.incidentBloc.select(incidents.first.uuid);
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentsLoaded>()),
      emits(isA<IncidentSelected>()),
    ]);
  });

  test('First incident should be selected in last state', () async {
    List<Incident> incidents = await harness.incidentBloc.load();
    await harness.incidentBloc.select(incidents.first.uuid);
    expect(harness.incidentBloc.selected.uuid, incidents.first.uuid, reason: "First incident was not selected");
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentsLoaded>()),
      emits(isA<IncidentSelected>()),
    ]);
  });

  test('Should create, update and delete incidents', () async {
    final token = UserServiceMock.createToken("user@lokalhost", "Commander");
    final incident = Incident.fromJson(IncidentBuilder.createIncidentAsJson("random", 0, token.accessToken, "123"));
    var response = await harness.incidentBloc.create(incident);
    expect(incident, isA<Incident>(), reason: "Should be an Incident");
    expect(incident.uuid, isNot(response.uuid), reason: "Response should have unique id");
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentUnset>()),
      emits(isA<IncidentSelected>()),
      emits(isA<IncidentCreated>()),
    ]);
    await harness.incidentBloc.update(response.withAuthor("author@localhost"));
    response = harness.incidentBloc.selected;
    expect(response.changed.userId, "author@localhost", reason: "Should be 'author@localhost'");
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentCreated>()),
      emits(isA<IncidentUpdated>()),
    ]);
  });

  test('Should be empty and no incidents should be selected after clear', () async {
    await harness.incidentBloc.load();
    await harness.incidentBloc.clear();
    expect(harness.incidentBloc.incidents.length, 0, reason: "Bloc should not containt incidents");
    expect(harness.incidentBloc.isEmpty, isTrue, reason: "Bloc should be empty");
    expect(harness.incidentBloc.isUnset, isTrue, reason: "Bloc should not be in selected state");
  });

  test('Should be selected after switching to other incident', () async {
    List<Incident> incidents = await harness.incidentBloc.load();
    await harness.incidentBloc.select(incidents.first.uuid);
    expect(harness.incidentBloc.selected.uuid, incidents.first.uuid, reason: "First incident was not selected");
    await harness.incidentBloc.select(incidents.last.uuid);
    expect(harness.incidentBloc.selected.uuid, incidents.last.uuid, reason: "Last incident was not selected");
    await harness.incidentBloc.select(incidents.first.uuid);
    _assertEvents(harness.incidentBloc, [
      emits(isA<IncidentSelected>()),
      emits(isA<IncidentSelected>()),
    ]);
  });
}

void _assertEvents(IncidentBloc incidentBloc, List<StreamMatcher> events) {
  expect(
    incidentBloc.state,
    emitsInOrder(events),
    reason: "Bloc contained unexpected stream of events",
  );
}
