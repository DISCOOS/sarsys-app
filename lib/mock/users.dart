import 'package:SarSys/services/UserService.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class UserServiceMock extends Mock implements UserService {
  static UserService build(String username, String password) {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(username, password)).thenAnswer((_) async {
      var token = _createToken(username);
      await UserService.storage.write(key: 'test_token', value: token);
      return Future.value(true);
    });
    when(mock.login(argThat(isNot(equals(username))), argThat(isNot(equals(password)))))
        .thenAnswer((_) => Future.error("Feil brukernavn/passord"));
    when(mock.getToken()).thenAnswer((_) async => Future.value(await UserService.storage.read(key: "test_token")));
    when(mock.logout()).thenAnswer((_) async {
      await UserService.storage.delete(key: 'test_token');
    });

    return mock;
  }

  static UserService buildAny() {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(any, any)).thenAnswer((username) async {
      var token = _createToken(username.namedArguments['username']);
      await UserService.storage.write(key: 'test_token', value: token);
      return Future.value(true);
    });
    when(mock.getToken()).thenAnswer((_) async => Future.value(await UserService.storage.read(key: "test_token")));
    when(mock.logout()).thenAnswer((_) async {
      await UserService.storage.delete(key: 'test_token');
    });

    return mock;
  }

  static String _createToken(String username) {
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
