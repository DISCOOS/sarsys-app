import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Required since provider need access to service bindings prior to calling 'test()'
  WidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) {
    // The key is the asset key.
    String key = utf8.decode(message.buffer.asUint8List());
    // Manually load the file.
    var file = new File('$key');
    final Uint8List encoded = utf8.encoder.convert(file.readAsStringSync());
    return Future.value(encoded.buffer.asByteData());
  });

  // Initialize shared preferences for testing
  SharedPreferences.setMockInitialValues({});

  final baseRestUrl = Defaults.baseRestUrl;
  final assetConfig = 'assets/config/app_config.json';

  UserBloc userBloc;
  IncidentBloc incidentBloc;

  setUp(() async {
    final AppConfigService configService = AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', null);
    final UserService userService = UserServiceMock.buildAny(UserRole.Commander, configService);
    await userService.login('user@localhost', 'password');
    final IncidentService incidentService = IncidentServiceMock.build(
      userService,
      2,
      enumName(UserRole.Commander),
      "T123",
    );

    userBloc = UserBloc(userService);
    incidentBloc = IncidentBloc(incidentService, userBloc);
  });

  tearDown(() async {
    incidentBloc.dispose();
    userBloc.dispose();
  });

  test(
    'Incident bloc should be empty and unset',
    () async {
      expect(incidentBloc.isEmpty, isTrue, reason: "Incident bloc should be empty");
      expect(incidentBloc.isUnset, isTrue, reason: "Incident bloc should be unset");
      expect(incidentBloc.initialState, isA<IncidentUnset>(), reason: "Unexpected incident state");
      _assertEvents(incidentBloc, [
        emits(isA<IncidentUnset>()),
      ]);
    },
  );

  test('Incident bloc should contain two incidents', () async {
    List<Incident> incidents = await incidentBloc.fetch();
    expect(incidents.length, 2, reason: "Bloc should return two incidents");
    expect(incidentBloc.isEmpty, isFalse, reason: "Bloc should not be empty");
    expect(incidentBloc.isUnset, isTrue, reason: "Bloc should not be in seleted state");
    _assertEvents(incidentBloc, [
      emits(isA<IncidentsCleared>()),
      emits(isA<IncidentsLoaded>()),
    ]);
  });

  test('Incident bloc should be in selected state', () async {
    List<Incident> incidents = await incidentBloc.fetch();
    await incidentBloc.select(incidents.first.id);
    _assertEvents(incidentBloc, [
      emits(isA<IncidentsLoaded>()),
      emits(isA<IncidentSelected>()),
    ]);
  });

  test('First incident should be selected in last state', () async {
    List<Incident> incidents = await incidentBloc.fetch();
    await incidentBloc.select(incidents.first.id);
    expect(incidentBloc.current, incidents.first, reason: "First incident was not selected");
    _assertEvents(incidentBloc, [
      emits(isA<IncidentsLoaded>()),
      emits(isA<IncidentSelected>()),
    ]);
  });

  test('Should create, update and delete incidents', () async {
    final token = UserServiceMock.createToken("user@lokalhost", "Commander");
    final incident = Incident.fromJson(IncidentBuilder.createIncidentAsJson("random", 0, token, "123"));
    var response = await incidentBloc.create(incident);
    expect(incident, isA<Incident>(), reason: "Should be an Incident");
    expect(incident.id, isNot(response.id), reason: "Response should have unique id");
    _assertEvents(incidentBloc, [
      emits(isA<IncidentUnset>()),
      emits(isA<IncidentSelected>()),
      emits(isA<IncidentCreated>()),
    ]);
    await incidentBloc.update(response.withAuthor("author@localhost"));
    response = incidentBloc.current;
    expect(response.changed.userId, "author@localhost", reason: "Should be 'author@localhost'");
    _assertEvents(incidentBloc, [
      emits(isA<IncidentCreated>()),
      emits(isA<IncidentUpdated>()),
    ]);
  });

  test('Should be empty and no incidents should be selected after clear', () async {
    await incidentBloc.fetch();
    await incidentBloc.clear();
    expect(incidentBloc.incidents.length, 0, reason: "Bloc should not containt incidents");
    expect(incidentBloc.isEmpty, isTrue, reason: "Bloc should be empty");
    expect(incidentBloc.isUnset, isTrue, reason: "Bloc should not be in selected state");
  });
}

void _assertEvents(IncidentBloc incidentBloc, List<StreamMatcher> events) {
  expect(
    incidentBloc.state,
    emitsInOrder(events),
    reason: "Bloc contained unexpected stream of events",
  );
}