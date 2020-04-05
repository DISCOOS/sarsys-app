import 'dart:convert';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

abstract class UserService {
  UserService(this.configBloc);
  static final storage = new FlutterSecureStorage();
  final AppConfigBloc configBloc;

  Future<ServiceResponse<bool>> isSecured() async {
    try {
      final type = await storage.read(key: "security");
      return ServiceResponse.ok(body: type != null);
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to get security from storage",
        error: e,
      );
    }
  }

  Future<ServiceResponse<Security>> getSecurity({String userId}) async {
    try {
      final actualId = userId ?? await currentUserId();
      final json = await storage.read(key: "security_$actualId");
      if (json != null) {
        return ServiceResponse.ok(
          body: Security.fromJson(jsonDecode(json)).renew(),
        );
      }
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to get security from storage",
        error: e,
      );
    }
    return ServiceResponse.noContent();
  }

  Future<ServiceResponse<Security>> secure(Security security, {String userId}) async {
    try {
      var next;
      final actualId = userId ?? await currentUserId();
      final response = await getSecurity(userId: actualId);
      if (response.is200) {
        next = response.body.cloneWith(
          pin: security.pin,
          type: security.type,
          locked: security.locked,
          heartbeat: DateTime.now(),
        );
      } else {
        next = security.renew();
      }
      await configBloc.update(
        securityPin: security.pin,
        securityType: security.type,
        securityMode: security.mode,
      );
      await storage.write(
        key: "security_$actualId",
        value: jsonEncode(next.toJson()),
      );
      return ServiceResponse.ok(
        body: next,
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(error: e);
    }
  }

  Future<ServiceResponse<Security>> lock() async {
    try {
      final response = await getSecurity();
      if (response.is200) {
        return secure(response.body.cloneWith(
          locked: true,
        ));
      }
      return ServiceResponse.noContent();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(error: e);
    }
  }

  Future<ServiceResponse<Security>> unlock({String pin}) async {
    try {
      final response = await getSecurity();
      if (response.is200) {
        var security = response.body;
        if (security.locked == false || security.pin == pin) {
          security = security.cloneWith(
            locked: false,
            heartbeat: DateTime.now(),
          );
          await storage.write(
            key: "security",
            value: jsonEncode(security.toJson()),
          );
          return ServiceResponse.ok(
            body: security,
          );
        }
        return ServiceResponse.unauthorized();
      }
      return ServiceResponse.noContent();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        error: e,
      );
    }
  }

  /// Load given user from storage
  Future<ServiceResponse<User>> load({
    String userId,
    bool validate = true,
    bool refresh = true,
  }) async {
    final actualId = userId ?? await currentUserId();
    final result = await getToken(
      userId: actualId,
      validate: validate,
      refresh: refresh,
    );
    if (result.is200) {
      final security = await getSecurity(
        userId: userId,
      );
      return ServiceResponse.ok(
        body: result.body.toUser(
          security: security.body,
        ),
      );
    }
    return ServiceResponse.noContent();
  }

  /// Load all users from storage
  Future<ServiceResponse<List<User>>> loadAll({
    bool validate = false,
    bool refresh = false,
  }) async {
    final users = <User>[];
    final list = await _readUserIds();
    if (list.isNotEmpty) {
      await Future.forEach(
        list,
        (userId) async {
          final result = await load(
            userId: userId,
            validate: validate,
            refresh: refresh,
          );
          if (result.is200) {
            users.add(result.body);
          }
        },
      );
    }

    if (users.isNotEmpty) {
      return ServiceResponse.ok(body: users);
    }
    return ServiceResponse.noContent();
  }

  /// Authorize and get token
  Future<ServiceResponse<User>> login({
    String username,
    String password,
  });

  Future<ServiceResponse<User>> refresh({String userId}) async {
    return ServiceResponse.noContent<User>(
      message: 'Username $userId not found',
    );
  }

  /// Get current token from secure storage
  Future<ServiceResponse<AuthToken>> getToken({
    String userId,
    bool validate = true,
    bool refresh = true,
  }) async {
    try {
      final actualId = userId ?? await currentUserId();
      final current = await readToken(actualId);
      if (current != null) {
        if (!kReleaseMode) print("Token found for $actualId: $current");
        bool isValid = current.isValid;
        if (isValid || !validate) {
          if (!kReleaseMode) print("Token ${isValid ? 'still' : 'is not'} valid");
          return ServiceResponse.ok(
            body: current,
          );
        }
        // Get new token (was expired)
        if (refresh) {
          await this.refresh(
            userId: actualId,
          );
        }
        return ServiceResponse.ok(
          body: await readToken(userId),
        );
      }
    } on FormatException {
      await logout();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        error: e,
      );
    }
    return ServiceResponse.noContent();
  }

  /// Delete token for given username from secure storage
  Future<ServiceResponse<User>> logout({
    String userId,
  }) async {
    try {
      final actualId = userId ?? await currentUserId();
      final token = await readToken(actualId);
      await this.delete(actualId);
      if (token != null) {
        final result = await lock(/*userId: actualId*/);
        if (!kReleaseMode) print("Logged out user $actualId");
        if (result != null) {
          return ServiceResponse.ok(
            body: token.toUser(
              security: result.body,
            ),
          );
        }
      }
      return ServiceResponse.noContent(
        message: "No user logged in",
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to delete token from storage",
        error: e,
      );
    }
  }

  /// Clear all users (tokens and security) from secure store
  Future<ServiceResponse<List<User>>> clear() async {
    try {
      final response = await loadAll();
      if (response.is200) {
        final request = response.body.map(
          (user) => delete(
            user.userId,
            security: true,
          ),
        );
        await Future.wait(request);
      }
      return response;
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to clear all users from storage",
        error: e,
      );
    }
  }

  /// Get current user id from storage
  Future<String> currentUserId() async => await storage.read(key: "current_user_id");

  /// Read user id list
  Future<Set<String>> _readUserIds() async {
    final json = await storage.read(
      key: "user_id_list",
    );
    return List<String>.from(
      json == null ? {} : jsonDecode(json),
    ).toSet();
  }

  /// Read token for given username from storage
  @protected
  Future<AuthToken> readToken(String userId) async {
    final json = await storage.read(key: "token_$userId");
    return json == null
        ? null
        : AuthToken.fromJson(
            jsonDecode(json),
          );
  }

  /// Write token for given username to storage
  @protected
  Future<AuthToken> writeToken({
    @required String accessToken,
    String idToken,
    String refreshToken,
    DateTime accessTokenExpiration,
  }) async {
    final token = AuthToken(
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiration: accessTokenExpiration,
    );

    final userId = token.toUser().userId;

    // Write current username
    await UserService.storage.write(
      key: "current_user_id",
      value: userId,
    );

    // Write token for given user
    await UserService.storage.write(
      key: "token_$userId",
      value: jsonEncode(token.toJson()),
    );

    // Update user list
    Set<String> list = await _readUserIds();
    list.add(userId);
    await storage.write(
      key: "user_id_list",
      value: jsonEncode(
        list.toList(),
      ),
    );
    if (!kReleaseMode) print("Current user is: $userId");
    return token;
  }

  /// Delete token for given username from storage
  Future delete(
    String userId, {
    bool security: false,
  }) async {
    await storage.delete(key: 'token_$userId');
    if (security) {
      await storage.delete(key: 'security_$userId');
    }
    Set<String> list = await _readUserIds();
    list.remove(userId);
    await storage.write(
      key: "user_id_list",
      value: jsonEncode(
        list.toList(),
      ),
    );
    await _unset(userId: userId);
  }

  // Unset current user
  Future _unset({String userId, bool force = false}) async {
    if (userId == await currentUserId() || force) {
      await UserService.storage.delete(
        key: "current_user_id",
      );
    }
  }
}

class UserIdentityService extends UserService {
  UserIdentityService(this.client, AppConfigBloc bloc) : super(bloc);
  final http.Client client;

  static const String AUTHORIZE_ERROR_CODE = "authorize_failed";
  static const String TOKEN_ERROR_CODE = "token_failed";
  static const String AUTHORIZE_AND_EXCHANGE_CODE_FAILED = 'authorize_and_exchange_code_failed';
  static const List<String> USER_ERRORS = const [
    AUTHORIZE_ERROR_CODE,
    TOKEN_ERROR_CODE,
    AUTHORIZE_AND_EXCHANGE_CODE_FAILED,
  ];

  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final String _clientId = 'sarsys-app';
  final String _redirectUrl = 'sarsys.app://oauth/redirect';
  final String _logoutUrl = 'https://id.discoos.io/auth/realms/DISCOOS/protocol/openid-connect/logout';
  final String _discoveryUrl = 'https://id.discoos.io/auth/realms/DISCOOS/.well-known/openid-configuration';
  final List<String> _scopes = const ['openid', 'profile', 'email', 'offline_access', 'roles'];

  // Keycloak will use this to redirect to linked identity providers
  final Map<String, String> _idpHints = const {
    'rodekors.org': 'rodekors',
    'gmail.com': 'google',
    'discoos.org': 'google',
  };

  // Force login screen (google will always return current user if not)
  // For possible values,
  // see https://developer.okta.com/docs/reference/api/oidc/#parameter-details
  //
  final Map<String, String> _promptValues = const {
    'google': 'login',
  };

  /// Authorize and get token
  @override
  Future<ServiceResponse<User>> login({
    String username,
    String password,
    String idpHint,
  }) async {
    try {
      // Get current user
      final current = await readToken(
        await currentUserId(),
      );
      final user = current?.toUser();

      // Same username as current user?
      if (username != null) {
        if (username?.toLowerCase() == user?.uname?.toLowerCase()) {
          // Refresh token?
          if (current.isExpired) {
            return refresh(
              userId: user.userId,
            );
          }
          return _toUser(current);
        }
      }
      // Not same user - we need to logout from current session
      // Chrome Custom Tab or other external browser might cache
      // the sessions and some IdPs doesn't support that and will
      // show an error message about that to the user. Keycloak
      // is one of those.
      await logout(
        userId: user?.userId,
      );

      // Request a new session from idp
      final hint = idpHint ?? _toIdpHint(username);
      final prompt = [
        if (_promptValues.containsKey(hint)) _promptValues[hint],
      ];
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          loginHint: username,
          promptValues: prompt,
          additionalParameters: {
            if (hint != null) 'kc_idp_hint': hint,
          },
          discoveryUrl: _discoveryUrl,
        ),
      );

      // Write token and get user
      return _toUser(
        await _writeToken(
          response,
        ),
      );
    } on PlatformException catch (e) {
      if (USER_ERRORS.contains(e.code)) {
        return ServiceResponse.unauthorized(
          message: "Unauthorized",
        );
      }
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
      );
    }
  }

  @override
  Future<ServiceResponse<User>> refresh({String userId}) async {
    try {
      final actualId = userId ?? await super.currentUserId();
      final current = await readToken(actualId);
      if (current != null) {
        final response = await _appAuth.token(
          TokenRequest(
            _clientId,
            _redirectUrl,
            scopes: _scopes,
            discoveryUrl: _discoveryUrl,
            refreshToken: current.refreshToken,
          ),
        );
        return _toUser(
          await _writeToken(
            response,
          ),
        );
      }
      return super.refresh(
        userId: actualId,
      );
    } on PlatformException catch (e) {
      if (USER_ERRORS.contains(e.code)) {
        return ServiceResponse.unauthorized(
          message: "Unauthorized",
        );
      }
      return ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
      );
    }
  }

  /// Delete token from secure storage
  @override
  Future<ServiceResponse<User>> logout({
    String userId,
  }) async {
    try {
      final token = await getToken(
        userId: userId,
      );
      if (token.is200) {
        // Chrome Custom Tab or other external browsers used by
        // AppAuth will cache the session. Some IdPs doesn't support
        // multiple session and will complain that a user is already
        // logged in. Keycloak is one of those. This problems is
        // resolved by actively invalidating the session using the
        // openid connect logout endpoint.
        //
        final url = '$_logoutUrl?redirect_uri=$_redirectUrl';
        final response = await client.post(url, headers: {
          'Authorization': 'Bearer ${token.body.accessToken}',
        }, body: {
          'client_id': _clientId,
          'refresh_token': token.body.refreshToken,
        });
        print(response.statusCode);
      }
      return super.logout(
        userId: userId,
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to logout",
        error: e,
      );
    }
  }

  Future<ServiceResponse<User>> _toUser(AuthToken token) async {
    if (!kReleaseMode) print("Token written: $token");
    final security = await getSecurity(userId: token.userId);
    return ServiceResponse.ok(
      body: token.toUser(
        security: security.body,
      ),
    );
  }

  Future<AuthToken> _writeToken(TokenResponse response) async {
    final token = await writeToken(
      idToken: response.idToken,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpiration: response.accessTokenExpirationDateTime,
    );
    if (!kReleaseMode) print("Token written: $token");
    return token;
  }

  String _toIdpHint(String username) {
    final pattern = RegExp(".*.@(.*)");
    final matcher = pattern.firstMatch(username);
    if (matcher != null && _idpHints.containsKey(matcher.group(1))) {
      return _idpHints[matcher.group(1)];
    }
    return null;
  }
}

class UserCredentialsService extends UserService {
  UserCredentialsService(this.url, this.client, AppConfigBloc bloc) : super(bloc);
  final String url;
  final http.Client client;

  /// Authorize with basic auth and get token
  Future<ServiceResponse<User>> login({String username, String password}) async {
    // TODO: Change to http_client to get better control of timeout, retries etc.
    // TODO: Handle various login/network errors and throw appropriate errors
    try {
      var response = await http.post(
        url,
        body: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200) {
        final responseObject = jsonDecode(response.body);
        final token = await writeToken(
          accessToken: responseObject['token'],
        );
        final security = await getSecurity(userId: token.userId);
        return ServiceResponse.ok(
          body: token.toUser(
            security: security.body,
          ),
        );
      } else if (response.statusCode == 401) {
        // wrong credentials
        return ServiceResponse.unauthorized();
      } else if (response.statusCode == 403) {
        // Forbidden
        return ServiceResponse.forbidden();
      }
      return ServiceResponse(
        code: response.statusCode,
        message: response.reasonPhrase,
      );
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
      );
    }
  }
}
