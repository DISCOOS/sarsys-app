import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/repositories/app_config_repository.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'harness.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() async {
  final harness = BlocTestHarness()
    ..withConfigBloc()
    ..install();

  test(
    'AppConfig SHOULD be EMPTY',
    () async {
      // Assert
      expect(await harness.configBloc.isEmpty, isFalse, reason: "AppConfigBloc SHOULD contain have state");
      expect(harness.configBloc.repo.config, isNull, reason: "AppConfigRepository SHOULD not contain AppConfig");
      expect(harness.configBloc.initialState, isA<AppConfigEmpty>(), reason: "AppConfigBloc SHOULD be in EMPTY state");
      await emitsExactly(harness.configBloc, []);
    },
  );

  test(
    'AppConfig SHOULD initialize with default values',
    () async {
      // Act
      await harness.configBloc.init();

      // Assert
      await emitsExactly(harness.configBloc, [isA<AppConfigInitialized>()]);
      expect(await harness.configBloc.isEmpty, isFalse, reason: "AppConfigBloc SHOULD have state");
      expect(harness.configBloc.repo.config, isNotNull, reason: "AppConfigRepository SHOULD have AppConfig");
    },
  );

  test(
    'AppConfig SHOULD load with default values when online',
    () async {
      // Arrange
      harness.connectivity.cellular();

      // Act
      await harness.configBloc.load();

      // Assert
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>()]);
      expect(await harness.configBloc.isEmpty, isFalse, reason: "SHOULD contain have state");
      expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
    },
  );

  test(
    'AppConfig SHOULD load with default values when offline',
    () async {
      // Arrange
      harness.connectivity.offline();

      // Act
      await harness.configBloc.load();

      // Assert
      await emitsExactly(harness.configBloc, [isA<AppConfigLoaded>()]);
      expect(await harness.configBloc.isEmpty, isFalse, reason: "SHOULD contain have state");
      expect(harness.configBloc.config, isNotNull, reason: "SHOULD have AppConfig");
      expect(harness.configBloc.repo.getState(APP_CONFIG_VERSION)?.isLocal, isTrue, reason: "SHOULD HAVE local state");
    },
  );

//  test('Incident bloc should contain two incidents', () async {
//    List<Incident> incidents = await harness.incidentBloc.load();
//    expect(incidents.length, 2, reason: "Bloc should return two incidents");
//    expect(harness.incidentBloc.isEmpty, isFalse, reason: "Bloc should not be empty");
//    expect(harness.incidentBloc.isUnset, isTrue, reason: "Bloc should not be in seleted state");
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentsCleared>()),
//      emits(isA<IncidentsLoaded>()),
//    ]);
//  });
//
//  test('Incident bloc should be in selected state', () async {
//    List<Incident> incidents = await harness.incidentBloc.load();
//    await harness.incidentBloc.select(incidents.first.uuid);
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentsLoaded>()),
//      emits(isA<IncidentSelected>()),
//    ]);
//  });
//
//  test('First incident should be selected in last state', () async {
//    List<Incident> incidents = await harness.incidentBloc.load();
//    await harness.incidentBloc.select(incidents.first.uuid);
//    expect(harness.incidentBloc.selected.uuid, incidents.first.uuid, reason: "First incident was not selected");
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentsLoaded>()),
//      emits(isA<IncidentSelected>()),
//    ]);
//  });
//
//  test('Should create, update and delete incidents', () async {
//    final token = UserServiceMock.createToken("user@lokalhost", "Commander");
//    final incident = Incident.fromJson(IncidentBuilder.createIncidentAsJson("random", 0, token.accessToken, "123"));
//    var response = await harness.incidentBloc.create(incident);
//    expect(incident, isA<Incident>(), reason: "Should be an Incident");
//    expect(incident.uuid, isNot(response.uuid), reason: "Response should have unique id");
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentUnset>()),
//      emits(isA<IncidentSelected>()),
//      emits(isA<IncidentCreated>()),
//    ]);
//    await harness.incidentBloc.update(response.withAuthor("author@localhost"));
//    response = harness.incidentBloc.selected;
//    expect(response.changed.userId, "author@localhost", reason: "Should be 'author@localhost'");
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentCreated>()),
//      emits(isA<IncidentUpdated>()),
//    ]);
//  });
//
//  test('Should be empty and no incidents should be selected after clear', () async {
//    await harness.incidentBloc.load();
//    await harness.incidentBloc.clear();
//    expect(harness.incidentBloc.incidents.length, 0, reason: "Bloc should not containt incidents");
//    expect(harness.incidentBloc.isEmpty, isTrue, reason: "Bloc should be empty");
//    expect(harness.incidentBloc.isUnset, isTrue, reason: "Bloc should not be in selected state");
//  });
//
//  test('Should be selected after switching to other incident', () async {
//    List<Incident> incidents = await harness.incidentBloc.load();
//    await harness.incidentBloc.select(incidents.first.uuid);
//    expect(harness.incidentBloc.selected.uuid, incidents.first.uuid, reason: "First incident was not selected");
//    await harness.incidentBloc.select(incidents.last.uuid);
//    expect(harness.incidentBloc.selected.uuid, incidents.last.uuid, reason: "Last incident was not selected");
//    await harness.incidentBloc.select(incidents.first.uuid);
//    _assertEvents(harness.incidentBloc, [
//      emits(isA<IncidentSelected>()),
//      emits(isA<IncidentSelected>()),
//    ]);
//  });
}

//void _assertEvents(Bloc bloc, List<StreamMatcher> events) {
//  expect(
//    bloc.state,
//    emitsInOrder(events),
//    reason: "Bloc contained unexpected stream of events",
//  );
//}

Future<void> emitsStorageStates<S, T>(
  ConnectionAwareRepository<S, T> repo,
  Iterable expected, {
  int skip = 1,
}) async {
  assert(repo != null);
  final states = <StorageState<T>>[];
  final subscription = repo.changes.skip(skip).listen(states.add);
  expect(states, expected);
  await subscription.cancel();
}
