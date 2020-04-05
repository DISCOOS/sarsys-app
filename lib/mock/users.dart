import 'dart:convert';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserServiceMock extends Mock implements UserCredentialsService {
  static UserCredentialsService build(UserRole role, AppConfigService configService, String username, String password) {
    final UserServiceMock mock = UserServiceMock();

    when(mock.login(username: username, password: password)).thenAnswer((_) async {
      var response = await configService.load();
      var actual = response.body.toRole(defaultValue: role);
      var token = createToken(username, enumName(actual));
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(token.toJson());
      await prefs.setString('test_token', json);
      return ServiceResponse.ok(body: token.toUser());
    });
    when(
      mock.login(
        username: argThat(isNot(equals(username))),
        password: argThat(isNot(equals(password))),
      ),
    ).thenAnswer(
      (_) async => ServiceResponse.unauthorized(message: "Feil brukernavn/passord"),
    );
    when(mock.load()).thenAnswer(
      (_) async => ServiceResponse.ok(body: (await _getToken(role, configService)).body.toUser()),
    );
    when(mock.getToken()).thenAnswer(
      (_) async => await _getToken(role, configService),
    );
    when(mock.logout()).thenAnswer((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static UserCredentialsService buildAny(UserRole role, AppConfigService configService) {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(username: anyNamed('username'), password: anyNamed('password'))).thenAnswer((_) async {
      var response = await configService.load();
      var actual = response.body.toRole(defaultValue: role);
      var token = createToken(_.namedArguments['username'], enumName(actual));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_token', jsonEncode(token.toJson()));
      return ServiceResponse.ok(body: token.toUser());
    });
    when(mock.getToken()).thenAnswer(
      (_) async {
        return await _getToken(role, configService);
      },
    );
    when(mock.load()).thenAnswer(
      (_) async => ServiceResponse.ok(body: (await _getToken(role, configService)).body.toUser()),
    );
    when(mock.logout()).thenAnswer((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('test_token');
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static Future<ServiceResponse<AuthToken>> _getToken(UserRole role, AppConfigService configService) async {
    var response = await configService.load();
    var actual = response.body.toRole(defaultValue: role);
    final prefs = await SharedPreferences.getInstance();
    var token;
    var json = prefs.getString('test_token');
    if (json != null) {
      try {
        token = AuthToken.fromJson(jsonDecode(json));
        // Logout if not same role
        if (!token.toUser().roles.contains(actual)) {
          token = null;
          prefs.remove('test_token');
        }
      } catch (e) {
        json = null;
        prefs.remove('test_token');
      }
    }
    return token == null
        ? ServiceResponse.notFound(message: "Token not found")
        : ServiceResponse.ok(
            body: token,
          );
  }

  static AuthToken createToken(String username, String role) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
        subject: username,
        issuer: 'rkh',
        otherClaims: <String, dynamic>{
          'roles': [role],
        },
        maxAge: const Duration(minutes: 5));

    return AuthToken(accessToken: issueJwtHS256(claimSet, key));
  }
}
