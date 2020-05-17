import 'dart:convert';
import 'dart:math' as math;
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';
import 'package:uuid/uuid.dart';

const PASSCODE = 'T123';

class IncidentBuilder {
  static Incident create(
    String userId, {
    int since = 0,
    String uuid,
    String passcode = PASSCODE,
  }) {
    return Incident.fromJson(
      createIncidentAsJson(
        uuid ?? Uuid().v4(),
        since,
        userId,
        passcode,
      ),
    );
  }

  static Map<String, dynamic> createIncidentAsJson(String uuid, int since, String userId, String passcode) {
    final rnd = math.Random();
    return json.decode(
      '{'
      '"uuid": "$uuid",'
      '"name": "Savnet person",'
      '"type": "Lost",'
      '"status": "Handling",'
      '"reference": "2019-RKH-245$since",'
      '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
      '"justification": "Mann, 32 år, økt selvmordsfare.",'
      '"ipp": ${createLocationAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
      '"meetup": ${createLocationAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
      '"talkgroups": ['
      '{"name": "RK-RIKS-1", "type": "Tetra"}'
      '],'
      '"exercise": true,'
      '"passcodes": ${createPasscodesAsJson(passcode)},'
      '"created": ${createAuthor(userId)},'
      '"changed": ${createAuthor(userId)}'
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

  static createRandomPasscodesAsJson() {
    return json.encode(Passcodes.random(6).toJson());
  }

  static createPasscodesAsJson(String passcode) {
    return json.encode(Passcodes(command: passcode, personnel: passcode).toJson());
  }

  static createAuthor(String userId) => json.encode(Author.now(userId));
}

class IncidentServiceMock extends Mock implements IncidentService {
  static final Map<String, Incident> incidents = {};

  Incident add(
    String userId, {
    int since = 0,
    String uuid,
    String passcode = PASSCODE,
  }) {
    final incident = IncidentBuilder.create(
      userId,
      uuid: uuid,
      since: since,
      passcode: passcode,
    );
    incidents[incident.uuid] = incident;
    return incident;
  }

  Incident remove(uuid) {
    return incidents.remove(uuid);
  }

  IncidentServiceMock reset() {
    incidents.clear();
    return this;
  }

  static MapEntry<String, Incident> _buildEntry(
    String uuid,
    int since,
    User user,
    String passcode,
  ) =>
      MapEntry(
        uuid,
        Incident.fromJson(
          IncidentBuilder.createIncidentAsJson(
            uuid,
            since,
            user.userId,
            passcode,
          ),
        ),
      );

  static IncidentService build(
    UserRepository repo, {
    @required final UserRole role,
    @required final String passcode,
    final int count = 0,
  }) {
    incidents.clear();
    final IncidentServiceMock mock = IncidentServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized", role).toUser();
    when(mock.fetch()).thenAnswer((_) async {
      if (incidents.isEmpty) {
        var user = await repo.load();
        incidents.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i, user, passcode),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i, unauthorized, passcode)
        ]);
      }
      return ServiceResponse.ok(body: incidents.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final authorized = await repo.load();
      final Incident incident = _.positionalArguments[0];
      final author = Author.now(authorized.userId);
      final created = Incident(
        uuid: incident.uuid ?? "m:${randomAlphaNumeric(8).toLowerCase()}",
        type: incident.type,
        status: incident.status,
        created: author,
        changed: author,
        occurred: incident.occurred,
        ipp: incident.ipp,
        meetup: incident.meetup,
        name: incident.name,
        justification: incident.justification,
        passcodes: Passcodes(
          command: passcode,
          personnel: passcode,
        ),
        talkgroups: incident.talkgroups,
        reference: incident.reference,
      );
      incidents.putIfAbsent(created.uuid, () => created);
      return ServiceResponse.ok(body: created);
    });
    when(mock.update(any)).thenAnswer((_) async {
      var incident = _.positionalArguments[0];
      if (incidents.containsKey(incident.uuid)) {
        incidents.update(
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
      if (incidents.containsKey(uuid)) {
        incidents.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident $uuid");
    });
    return mock;
  }
}
