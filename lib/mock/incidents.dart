import 'dart:convert';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Author.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Passcodes.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:jose/jose.dart';
import 'package:mockito/mockito.dart';

class IncidentBuilder {
  static createIncidentFromToken(String id, int since, String token, String passcode) {
    return json.decode(createIncidentAsJson(id, since, token, passcode));
  }

  static createIncidentAsJson(String id, int since, String token, String passcode) {
    return '{'
        '"id": "$id",'
        '"name": "Savnet person",'
        '"type": "Lost",'
        '"status": "Handling",'
        '"reference": "2019-RKH-245$since",'
        '"occurred": "${DateTime.now().subtract(Duration(hours: since)).toIso8601String()}",'
        '"justification": "Mann, 32 år, økt selvmordsfare.",'
        '"ipp": ${createEmptyPointAsJson()},'
        '"talkgroups": ['
        '{"name": "RK-RIKS-1", "type": "Tetra"}'
        '],'
        '"passcodes": ${createPasscodesAsJson(passcode)},'
        '"created": ${createAuthor(token)},'
        '"changed": ${createAuthor(token)}'
        '}';
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
    final IncidentServiceMock mock = IncidentServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized");
    when(mock.fetch()).thenAnswer((_) async {
      var authorized = await service.getToken();
      return Future.value([
        for (var i = 1; i <= count ~/ 2; i++)
          Incident.fromJson(IncidentBuilder.createIncidentFromToken("aZ$i", i, authorized, passcode)),
        for (var i = count ~/ 2 + 1; i <= count; i++)
          Incident.fromJson(IncidentBuilder.createIncidentFromToken("By$i", i, unauthorized, passcode)),
      ]);
    });
    return mock;
  }
}
