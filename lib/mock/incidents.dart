import 'dart:convert';
import 'dart:math' as math;
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:jose/jose.dart';
import 'package:mockito/mockito.dart';

class IncidentBuilder {
  static createIncidentFromToken(String id, int since, String token, String passcode) {
    return json.decode(createIncidentAsJson(id, since, token, passcode));
  }

  static createIncidentAsJson(String id, int since, String token, String passcode) {
    final rnd = math.Random();
    return '{'
        '"id": "$id",'
        '"name": "Savnet person",'
        '"type": "Lost",'
        '"status": "Handling",'
        '"reference": "2019-RKH-245$since",'
        '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
        '"justification": "Mann, 32 år, økt selvmordsfare.",'
        '"ipp": ${createPointAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
        '"meetup": ${createPointAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
        '"talkgroups": ['
        '{"name": "RK-RIKS-1", "type": "Tetra"}'
        '],'
        '"passcodes": ${createPasscodesAsJson(passcode)},'
        '"created": ${createAuthor(token)},'
        '"changed": ${createAuthor(token)}'
        '}';
  }

  static createPointAsJson(double lat, double lon) {
    return json.encode(Point.now(lat, lon).toJson());
  }

  static createEmptyPointAsJson() {
    return json.encode(Point.now(0, 0).toJson());
  }

  static createRandomPasscodesAsJson() {
    return json.encode(Passcodes.random(6).toJson());
  }

  static createPasscodesAsJson(String passcode) {
    return json.encode(Passcodes(command: passcode, personnel: passcode).toJson());
  }

  static createAuthor(String token) {
    var jwt = new JsonWebToken.unverified(token);
    return json.encode(Author.now(jwt.claims.subject));
  }
}

class IncidentServiceMock extends Mock implements IncidentService {
  static IncidentService build(UserService service, final int count, final String passcode) {
    final Map<String, Incident> incidents = {};
    final IncidentServiceMock mock = IncidentServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized");
    when(mock.fetch()).thenAnswer((_) async {
      if (incidents.isEmpty) {
        var response = await service.getToken();
        incidents.addEntries([
          for (var i = 1; i <= count ~/ 2; i++)
            MapEntry(
              "aZ$i",
              Incident.fromJson(IncidentBuilder.createIncidentFromToken("aZ$i", i, response.body, passcode)),
            ),
          for (var i = count ~/ 2 + 1; i <= count; i++)
            MapEntry(
              "By$i",
              Incident.fromJson(IncidentBuilder.createIncidentFromToken("By$i", i, unauthorized, passcode)),
            ),
        ]);
      }
      return ServiceResponse.ok(body: incidents.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final response = await service.getToken();
      final authorized = JsonWebToken.unverified(response.body);
      final Incident incident = _.positionalArguments[0];
      final author = Author.now(authorized.claims.subject);
      final created = Incident(
        id: "aZ${incidents.length + 1}",
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
      return ServiceResponse.ok(body: created);
    });
    when(mock.update(any)).thenAnswer((_) async {
      var incident = _.positionalArguments[0];
      if (incidents.containsKey(incident.id)) {
        incidents.update(
          incident.id,
          (_) => incident,
          ifAbsent: () => incident,
        );
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident ${incident.id}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var incident = _.positionalArguments[0];
      if (incidents.containsKey(incident.id)) {
        incidents.remove(incident.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Incident ${incident.id}");
    });
    return mock;
  }
}
