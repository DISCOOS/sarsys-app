import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class UserServiceMock extends Mock implements UserCredentialsService {
  static String get username => _username;
  static String _username;

  static String get password => _password;
  static String _password;

  static String get division => _division;
  static String _division;

  static String get department => _department;
  static String _department;

  static Duration get maxAge => _maxAge;
  static Duration _maxAge = const Duration(minutes: 5);

  void setCredentials({
    String username,
    String password,
    Duration maxAge = const Duration(minutes: 5),
  }) {
    UserServiceMock._username = username ?? UserServiceMock._username;
    UserServiceMock._password = password ?? UserServiceMock._password;
    UserServiceMock._maxAge = maxAge ?? UserServiceMock._maxAge;
  }

  AuthToken invalidateToken() {
    final token = _token;
    if (_token != null) {
      final user = _token.toUser();
      _token = createToken(
        _token.userId,
        user.roles.first,
        email: user.email,
        division: user.division,
        department: user.department,
        maxAge: Duration.zero,
      );
    }
    return token;
  }

  AuthToken get token => _token;
  static AuthToken _token;

  static UserServiceMock build({
    @required UserRole role,
    @required String userId,
    @required String username,
    @required String password,
    @required String division,
    @required String department,
  }) {
    final UserServiceMock mock = UserServiceMock();
    UserServiceMock._username = username;
    UserServiceMock._password = password;
    UserServiceMock._division = division;
    UserServiceMock._department = department;

    when(
      mock.login(
        userId: anyNamed('userId'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async {
      final requestedUserId = _.namedArguments[Symbol('userId')];
      if (requestedUserId != null && requestedUserId == _token?.userId && _token.isValid) {
        return ServiceResponse.ok(body: _token);
      } else if (_credentialsMatch(_)) {
        final domain = UserService.toDomain(UserServiceMock.username);
        _token = createToken(
          userId ?? UserServiceMock.username,
          role,
          maxAge: _maxAge,
          division: _division,
          department: _department,
          email: domain != null ? UserServiceMock.username : domain,
        );
        return ServiceResponse.ok(body: _token);
      }
      return ServiceResponse.unauthorized();
    });
    when(
      mock.login(
        username: argThat(isNot(equals(UserServiceMock.username)), named: 'username'),
        password: argThat(isNot(equals(UserServiceMock.password)), named: 'password'),
      ),
    ).thenAnswer(
      (_) async => ServiceResponse.unauthorized(),
    );
    when(mock.refresh(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      final user = _token.toUser();
      _token = createToken(
        token.userId,
        token.toUser().roles.first,
        maxAge: _maxAge,
        email: user.email,
        division: user.division,
        department: user.department,
      );
      return ServiceResponse.ok(body: _token);
    });
    when(mock.logout(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      if (token.userId == _token?.userId) {
        _token = null;
      }
      return ServiceResponse.noContent();
    });

    return mock;
  }

  static UserRole toRole(AppConfigRepository configRepo, UserRole role) {
    var config = configRepo.config;
    if (config != null) {
      return config.toRole(defaultValue: role);
    }
    return role;
  }

  static bool _credentialsMatch(Invocation _) {
    return _username == _.namedArguments[Symbol('username')] && _password == _.namedArguments[Symbol('password')];
  }

  static UserServiceMock buildAny(UserRole role, AppConfigRepository configRepo) {
    final UserServiceMock mock = UserServiceMock();
    when(
      mock.login(
        username: anyNamed('username'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async {
      UserRole actual = toRole(configRepo, role);
      final domain = UserService.toDomain(username);
      _token = createToken(
        username,
        actual,
        maxAge: _maxAge,
        email: domain != null ? username : domain,
      );
      return ServiceResponse.ok(body: _token);
    });
    when(mock.refresh(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      final user = _token.toUser();
      _token = createToken(
        token.userId,
        user.roles.first,
        maxAge: _maxAge,
        email: user.email,
        division: user.division,
        department: user.department,
      );
      return ServiceResponse.ok(body: _token);
    });
    when(mock.logout(any)).thenAnswer((_) async {
      final token = _.positionalArguments[0] as AuthToken;
      if (token.userId == _token?.userId) {
        _token = null;
      }
      return ServiceResponse.noContent();
    });
    return mock;
  }

  static AuthToken createToken(
    String userId,
    UserRole role, {
    String email,
    String division,
    String department,
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
      subject: userId,
      issuer: 'rkh',
      otherClaims: <String, dynamic>{
        if (email != null) 'email': email,
        'roles': [enumName(role)],
        'division': division,
        'department': department,
      },
      maxAge: maxAge,
    );
    return AuthToken(
      accessToken: issueJwtHS256(claimSet, key),
      accessTokenExpiration: DateTime.now().add(maxAge),
    );
  }
}
