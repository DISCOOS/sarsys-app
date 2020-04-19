import 'dart:convert';
import 'dart:math' as math;
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';

class IncidentBuilder {
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
      '"passcodes": ${createPasscodesAsJson(passcode)},'
      '"created": ${createAuthor(userId)},'
      '"changed": ${createAuthor(userId)}'
      '}',
    );
  }

  static createLocationAsJson(double lat, double lon) {
    return json.encode(Location(point: Point.now(lat, lon)).toJson());
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
  static IncidentService build(UserRepository repo, final int count, final String role, final String passcode) {
    final Map<String, Incident> incidents = {};
    final IncidentServiceMock mock = IncidentServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized", role);
    when(mock.load()).thenAnswer((_) async {
      if (incidents.isEmpty) {
        var user = await repo.load();
        incidents.addEntries([
          for (var i = 1; i <= count ~/ 2; i++)
            MapEntry(
              "a:x$i",
              Incident.fromJson(
                IncidentBuilder.createIncidentAsJson("a:x$i", i, user.userId, passcode),
              ),
            ),
          for (var i = count ~/ 2 + 1; i <= count; i++)
            MapEntry(
              "a:y$i",
              Incident.fromJson(
                IncidentBuilder.createIncidentAsJson("a:y$i", i, unauthorized.toUser().userId, passcode),
              ),
            ),
        ]);
      }
      return ServiceResponse.ok(body: incidents.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final authorized = await repo.load();
      final Incident incident = _.positionalArguments[0];
      final author = Author.now(authorized.userId);
      final created = Incident(
        uuid: "m:${randomAlphaNumeric(8).toLowerCase()}",
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
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident ${incident.uuid}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var incident = _.positionalArguments[0];
      if (incidents.containsKey(incident.uuid)) {
        incidents.remove(incident.uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident ${incident.uuid}");
    });
    return mock;
  }
}
