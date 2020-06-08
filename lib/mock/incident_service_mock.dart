import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/services/service.dart';

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
  static final Map<String, Incident> _incidents = {};

  Incident add({
    String uuid,
    int since = 0,
  }) {
    final incident = IncidentBuilder.create(
      uuid: uuid,
      since: since,
    );
    _incidents[incident.uuid] = incident;
    return incident;
  }

  Incident remove(uuid) {
    return _incidents.remove(uuid);
  }

  IncidentServiceMock reset() {
    _incidents.clear();
    return this;
  }

  static MapEntry<String, Incident> _buildEntry(
    String uuid,
    int since,
  ) =>
      MapEntry(
        uuid,
        IncidentModel.fromJson(
          IncidentBuilder.createIncidentAsJson(
            uuid,
            since,
          ),
        ),
      );

  static IncidentService build(
    UserRepository users, {
    @required final UserRole role,
    @required final String passcode,
    final int count = 0,
  }) {
    _incidents.clear();
    final IncidentServiceMock mock = IncidentServiceMock();
    when(mock.fetch()).thenAnswer((_) async {
      final authorized = await users.load();
      if (authorized == null) {
        return ServiceResponse.unauthorized();
      }
      if (_incidents.isEmpty) {
        _incidents.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i)
        ]);
      }
      return ServiceResponse.ok(body: _incidents.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final authorized = await users.load();
      if (authorized == null) {
        return ServiceResponse.unauthorized();
      }
      final Incident incident = _.positionalArguments[0];
      final created = IncidentModel(
        uuid: incident.uuid,
        name: incident.name,
        type: incident.type,
        status: incident.status,
        summary: incident.summary,
        occurred: incident.occurred,
        resolution: incident.resolution,
      );
      _incidents.putIfAbsent(created.uuid, () => created);
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      var incident = _.positionalArguments[0];
      if (_incidents.containsKey(incident.uuid)) {
        _incidents.update(
          incident.uuid,
          (_) => incident,
          ifAbsent: () => incident,
        );
        return ServiceResponse.ok(body: incident);
      }
      return ServiceResponse.notFound(message: "Not found. Incident ${incident.uuid}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var uuid = _.positionalArguments[0];
      if (_incidents.containsKey(uuid)) {
        _incidents.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident $uuid");
    });
    return mock;
  }
}
