import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserServiceMock extends Mock implements UserService {
  static UserService build(UserRole role, AppConfigService configService, String username, String password) {
    final UserServiceMock mock = UserServiceMock();

    when(mock.login(username, password)).thenAnswer((_) async {
      var response = await configService.fetch();
      var actual = response.body.toRole(defaultValue: role);
      var token = createToken(username, enumName(actual));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_token', token);
      return ServiceResponse.ok(body: token);
    });
    when(mock.login(argThat(isNot(equals(username))), argThat(isNot(equals(password))))).thenAnswer(
      (_) async => ServiceResponse.unauthorized(message: "Feil brukernavn/passord"),
    );
    when(mock.getToken()).thenAnswer(
      (_) async {
        return await _getToken(role, configService);
      },
    );
    when(mock.logout()).thenAnswer((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static UserService buildAny(UserRole role, AppConfigService configService) {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(any, any)).thenAnswer((_) async {
      var response = await configService.fetch();
      var actual = response.body.toRole(defaultValue: role);
      var token = createToken(_.positionalArguments[0], enumName(actual));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_token', token);
      return ServiceResponse.ok(body: token);
    });
    when(mock.getToken()).thenAnswer(
      (_) async {
        return await _getToken(role, configService);
      },
    );
    when(mock.logout()).thenAnswer((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static Future<ServiceResponse<String>> _getToken(UserRole role, AppConfigService configService) async {
    var response = await configService.fetch();
    var actual = response.body.toRole(defaultValue: role);
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('test_token');
    if (token != null) {
      try {
        final user = User.fromToken(token);
        // Logout if not same role
        if (!user.roles.contains(actual)) {
          token = null;
          prefs.remove('test_token');
        }
      } catch (e) {
        token = null;
        prefs.remove('test_token');
      }
    }
    return token == null ? ServiceResponse.notFound(message: "Token not found") : ServiceResponse.ok(body: token);
  }

  static String createToken(String username, String role) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
        subject: username,
        issuer: 'rkh',
        otherClaims: <String, dynamic>{
          'roles': [role],
        },
        maxAge: const Duration(minutes: 5));

    return issueJwtHS256(claimSet, key);
  }
}
