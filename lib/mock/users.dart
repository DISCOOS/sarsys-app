import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/features/app_config/domain/repositories/app_config_repository.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:matcher/matcher.dart';
import 'package:mockito/mockito.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class UserServiceMock extends Mock implements UserCredentialsService {
  static String get username => _username;
  static String _username;

  static String get password => _password;
  static String _password;

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
        maxAge: Duration.zero,
      );
    }
    return token;
  }

  AuthToken get token => _token;
  static AuthToken _token;

  static UserServiceMock build(UserRole role, String username, String password) {
    final UserServiceMock mock = UserServiceMock();
    UserServiceMock._username = username;
    UserServiceMock._password = password;

    when(
      mock.login(
        userId: anyNamed('userId'),
        username: anyNamed('username'),
        password: anyNamed('password'),
      ),
    ).thenAnswer((_) async {
      final userId = _.namedArguments[Symbol('userId')];
      if (userId != null && userId == _token?.userId && _token.isValid) {
        return ServiceResponse.ok(body: _token);
      } else if (_credentialsMatch(_)) {
        final domain = UserService.toDomain(UserServiceMock.username);
        _token = createToken(
          UserServiceMock.username,
          role,
          maxAge: _maxAge,
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
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final key = 's3cr3t';
    final claimSet = new JwtClaim(
      subject: userId,
      issuer: 'rkh',
      otherClaims: <String, dynamic>{
        if (email != null) 'email': email,
        'roles': [enumName(role)],
        'division': 'Oslo',
        'department': 'Oslo',
      },
      maxAge: maxAge,
    );
    return AuthToken(
      accessToken: issueJwtHS256(claimSet, key),
      accessTokenExpiration: DateTime.now().add(maxAge),
    );
  }
}
