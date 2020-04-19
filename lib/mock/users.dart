import 'dart:convert';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/app_config_repository.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class UserServiceMock extends Mock implements UserCredentialsService {
  static UserCredentialsService build(UserRole role, AppConfigRepository configRepo, String username, String password) {
    final UserServiceMock mock = UserServiceMock();

    when(mock.login(username: username, password: password)).thenAnswer((_) async {
      var config = configRepo.config;
      var actual = config.toRole(defaultValue: role);
      var token = createToken(username, enumName(actual));
      final json = jsonEncode(token.toJson());
      await Storage.secure.write(
        key: 'test_token_${token.userId}',
        value: json,
      );
      return ServiceResponse.ok(body: token);
    });
    when(
      mock.login(
        username: argThat(isNot(equals(username))),
        password: argThat(isNot(equals(password))),
      ),
    ).thenAnswer(
      (_) async => ServiceResponse.unauthorized(message: "Feil brukernavn/passord"),
    );
    when(mock.refresh(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      final json = jsonEncode(token.toJson());
      await Storage.secure.write(
        key: 'test_token_${token.userId}',
        value: json,
      );
      return ServiceResponse.ok(body: token);
    });
    when(mock.logout(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      await Storage.secure.delete(
        key: 'test_token_${token.userId}',
      );
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static UserCredentialsService buildAny(UserRole role, AppConfigRepository configRepo) {
    final UserServiceMock mock = UserServiceMock();
    when(mock.login(username: anyNamed('username'), password: anyNamed('password'))).thenAnswer((_) async {
      var config = configRepo.config;
      var actual = config.toRole(defaultValue: role);
      var token = createToken(_.namedArguments['username'], enumName(actual));
      final json = jsonEncode(token.toJson());
      await Storage.secure.write(
        key: 'test_token_${token.userId}',
        value: json,
      );
      return ServiceResponse.ok(body: token);
    });
    when(mock.refresh(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      final json = jsonEncode(token.toJson());
      await Storage.secure.write(
        key: 'test_token_${token.userId}',
        value: json,
      );
      return ServiceResponse.ok(body: token);
    });
    when(mock.logout(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      await Storage.secure.delete(
        key: 'test_token_${token.userId}',
      );
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static AuthToken createToken(String username, String role) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
        subject: username,
        issuer: 'rkh',
        otherClaims: <String, dynamic>{
          'roles': [role],
          'division': 'Oslo',
          'department': 'Oslo',
        },
        maxAge: const Duration(minutes: 5));

    return AuthToken(accessToken: issueJwtHS256(claimSet, key));
  }
}
