import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class UserServiceMock extends Mock implements UserService {
  static UserService build(String username, String password) {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(username, password)).thenAnswer((_) async {
      var token = createToken(username);
      await UserService.storage.write(key: 'test_token', value: token);
      return ServiceResponse.ok(body: token);
    });
    when(mock.login(argThat(isNot(equals(username))), argThat(isNot(equals(password))))).thenAnswer(
      (_) async => ServiceResponse.unauthorized(message: "Feil brukernavn/passord"),
    );
    when(mock.getToken()).thenAnswer(
      (_) async {
        final token = await UserService.storage.read(key: "test_token");
        return token == null
            ? ServiceResponse.unauthorized(message: "Token not found")
            : ServiceResponse.ok(body: token);
      },
    );
    when(mock.logout()).thenAnswer((_) async {
      await UserService.storage.delete(key: 'test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static UserService buildAny() {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(any, any)).thenAnswer((username) async {
      var token = createToken(username.positionalArguments[0]);
      await UserService.storage.write(key: 'test_token', value: token);
      return ServiceResponse.ok(body: token);
    });
    when(mock.getToken()).thenAnswer(
      (_) async {
        final token = await UserService.storage.read(key: "test_token");
        return token == null
            ? ServiceResponse.unauthorized(message: "Token not found")
            : ServiceResponse.ok(body: token);
      },
    );
    when(mock.logout()).thenAnswer((_) async {
      await UserService.storage.delete(key: 'test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static String createToken(String username) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
        subject: username,
        issuer: 'rkh',
        otherClaims: <String, dynamic>{
          'roles': ['pilot', 'al'],
        },
        maxAge: const Duration(minutes: 5));

    return issueJwtHS256(claimSet, key);
  }
}
