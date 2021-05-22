import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/core/data/services/service.dart';

class IncidentBuilder {
  static Incident create({
    String uuid,
    int since = 0,
  }) {
    return IncidentModel.fromJson(
      createIncidentAsJson(
        uuid ?? Uuid().v4(),
        since,
      ),
    );
  }

  static Map<String, dynamic> createIncidentAsJson(String uuid, int since) {
    return json.decode(
      '{'
      '"uuid": "$uuid",'
      '"name": "Savnet person",'
      '"type": "lost",'
      '"status": "registered",'
      '"resolution": "unresolved",'
      '"summary": "Mann, 32 år, økt selvmordsfare.",'
      '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
      '"exercise": true'
      '}',
    );
  }

  static createLocationAsJson(double lat, double lon) {
    return json.encode(Location(
      point: Point.fromCoords(
        lat: lat,
        lon: lon,
      ),
    ).toJson());
  }
}

class IncidentServiceMock extends Mock implements IncidentService {
  static final Map<String, StorageState<Incident>> _incidentRepo = {};

  Incident add({
    String uuid,
    int since = 0,
  }) {
    final incident = IncidentBuilder.create(
      uuid: uuid,
      since: since,
    );
    final state = StorageState.created(
      incident,
      StateVersion.first,
      isRemote: true,
    );
    _incidentRepo[incident.uuid] = state;
    return incident;
  }

  StorageState<Incident> remove(uuid) {
    return _incidentRepo.remove(uuid);
  }

  IncidentServiceMock reset() {
    _incidentRepo.clear();
    return this;
  }

  static MapEntry<String, StorageState<Incident>> _buildEntry(
    String uuid,
    int since,
  ) =>
      MapEntry(
        uuid,
        StorageState.created(
          IncidentModel.fromJson(
            IncidentBuilder.createIncidentAsJson(
              uuid,
              since,
            ),
          ),
          StateVersion.first,
          isRemote: true,
        ),
      );

  static IncidentService build(
    UserRepository users, {
    @required final UserRole role,
    @required final String passcode,
    final int count = 0,
  }) {
    _incidentRepo.clear();
    final IncidentServiceMock mock = IncidentServiceMock();
    final StreamController<IncidentMessage> controller = StreamController.broadcast();

    when(mock.getList()).thenAnswer((_) async {
      final user = await users.load();
      if (user == null) {
        return ServiceResponse.unauthorized();
      }
      if (_incidentRepo.isEmpty) {
        _incidentRepo.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i)
        ]);
      }
      return ServiceResponse.ok(body: _incidentRepo.values.toList(growable: false));
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.create(any)).thenAnswer((_) async {
      final user = await users.load();
      if (user == null) {
        return ServiceResponse.unauthorized();
      }
      final state = _.positionalArguments[0] as StorageState<Incident>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final uuid = state.value.uuid;
      _incidentRepo[uuid] = state.remote(
        state.value,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: _incidentRepo[uuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Incident>;
      final uuid = next.value.uuid;
      if (_incidentRepo.containsKey(uuid)) {
        final state = _incidentRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        _incidentRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: _incidentRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Incident not found: $uuid",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Incident>;
      final uuid = state.value.uuid;
      if (_incidentRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: _incidentRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Incident not found: $uuid",
      );
    });
    return mock;
  }
}
