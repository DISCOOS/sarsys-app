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

  /// Check if users are sharing same device
  bool get sharedMode => SecurityMode.shared == configBloc.config.securityMode;

  /// Check if device personal
  bool get personalMode => SecurityMode.personal == configBloc.config.securityMode;

  /// Check if [User] is in a trusted domain
  bool isTrusted(User user) => configBloc.config.trustedDomains.contains(toDomain(user.uname));

  Future<ServiceResponse<bool>> isSecured() async {
    try {
      final type = await storage.read(key: "security");
      return ServiceResponse.ok(body: type != null);
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to get security from storage",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ServiceResponse<User>> getUser({String userId}) async {
    try {
      final actualId = userId ?? await currentUserId();
      final json = await storage.read(key: "user_$actualId");
      if (json != null) {
        final user = User.fromJson(jsonDecode(json));
        return ServiceResponse.ok(
          body: user.cloneWith(
            security: user.security?.cloneWith(
              heartbeat: DateTime.now(),
              type: configBloc.config?.securityType,
              mode: configBloc.config?.securityMode,
            ),
          ),
        );
      }
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to get security from storage",
        error: e,
        stackTrace: stackTrace,
      );
    }
    return ServiceResponse.noContent();
  }

  Future<ServiceResponse<Security>> getSecurity({String userId}) async {
    try {
      final actualId = userId ?? await currentUserId();
      final json = await storage.read(key: "user_$actualId");
      if (json != null) {
        return ServiceResponse.ok(
          body: User.fromJson(jsonDecode(json)).security.cloneWith(
                heartbeat: DateTime.now(),
                type: configBloc.config?.securityType,
                mode: configBloc.config?.securityMode,
              ),
        );
      }
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to get security from storage",
        error: e,
        stackTrace: stackTrace,
      );
    }
    return ServiceResponse.noContent();
  }

  Future<ServiceResponse<Security>> secure(
    String pin, {
    String userId,
    bool locked,
    bool trusted,
  }) async {
    try {
      var next;
      final actualId = userId ?? await currentUserId();
      final response = await load(userId: actualId);
      if (response.is200) {
        final user = response.body;
        if (user.security != null) {
          next = user.security.cloneWith(
            pin: pin,
            locked: locked,
            heartbeat: DateTime.now(),
            trusted: trusted ?? isTrusted(user),
            type: configBloc.config.securityType,
            mode: configBloc.config.securityMode,
          );
        } else {
          next = Security(
            pin: pin,
            locked: locked ?? true,
            trusted: trusted ?? isTrusted(user),
            heartbeat: DateTime.now(),
            type: configBloc.config.securityType,
            mode: configBloc.config.securityMode,
          );
        }
        await configBloc.update(
          securityPin: pin,
        );
        await writeUser(
          user.cloneWith(security: next),
        );
        return ServiceResponse.ok(
          body: next,
        );
      }
      return ServiceResponse.notFound(
        message: 'User id $actualId not found',
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ServiceResponse<Security>> lock({String userId}) async {
    try {
      final response = await getSecurity(userId: userId);
      if (response.is200) {
        return secure(
          response.body.pin,
          locked: true,
        );
      }
      return ServiceResponse.noContent();
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
      );
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
            type: configBloc.config.securityType,
            mode: configBloc.config.securityMode,
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
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
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
    final token = await getToken(
      userId: actualId,
      validate: validate,
      refresh: refresh,
    );
    final user = await getUser(
      userId: userId,
    );
    if (token.is200) {
      return ServiceResponse.ok(
        body: await writeUser(
          token.body.toUser(
            security: user.is200 ? user.body.security : null,
          ),
        ),
      );
    } else if (user.is200) {
      return user;
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
    String userId,
    String username,
    String password,
    String idpHint,
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
        final token = await readToken(userId);
        if (token != null) {
          return ServiceResponse.ok(
            body: await readToken(userId),
          );
        }
        return ServiceResponse.noContent();
      }
    } on FormatException {
      await logout(
        userId: userId,
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
      );
    }
    return ServiceResponse.noContent();
  }

  /// Delete token for given username from secure storage
  Future<ServiceResponse<User>> logout({
    String userId,
    bool delete: false,
  }) async {
    try {
      final response = await load(
        userId: userId,
      );
      if (response.is200) {
        final user = response.body;
        await this.delete(
          user.userId,
          // Always delete untrusted users
          user: delete || user.isUntrusted,
        );
        if (sharedMode) {
          await lock(
            userId: user.userId,
          );
        }
        if (!kReleaseMode) print("Logged out user ${user.userId}");
        return ServiceResponse.ok(
          body: user,
        );
      }
      return ServiceResponse.noContent(
        message: "No user logged in",
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to delete token from storage",
        error: e,
        stackTrace: stackTrace,
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
            user: true,
          ),
        );
        await Future.wait(request);
      }
      return response;
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to clear all users from storage",
        error: e,
        stackTrace: stackTrace,
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

  /// Write user to storage
  @protected
  Future<User> writeUser(User user) async {
    await storage.write(
      key: "user_${user.userId}",
      value: jsonEncode(
        user.toJson(),
      ),
    );
    return user;
  }

  /// Write token to storage
  @protected
  Future<AuthToken> writeToken(
    String accessToken, {
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

  /// Delete token for given [userId] from storage
  Future delete(
    String userId, {
    bool user: false,
  }) async {
    await storage.delete(
      key: 'token_$userId',
    );
    if (user) {
      await storage.delete(
        key: 'user_$userId',
      );
      // TODO: Limit to N users removing the oldest first
      Set<String> list = await _readUserIds();
      list.remove(userId);
      await storage.write(
        key: "user_id_list",
        value: jsonEncode(
          list.toList(),
        ),
      );
    }
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

  static String toDomain(String username) {
    final pattern = RegExp(".*.@(.*)");
    final matcher = pattern.firstMatch(username);
    return matcher?.group(1);
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
  final List<String> _scopes = const [
    'openid',
    'profile',
    'email',
    'offline_access',
    'roles',
    'phone_number',
    'division',
    'department',
  ];

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
    String userId,
    String username,
    String password,
    String idpHint,
  }) async {
    try {
      // Get current user
      final currentToken = await readToken(
        await currentUserId(),
      );

      final currentUser = currentToken?.toUser();

      // Requested user is current user?
      if (currentToken != null) {
        if (userId == currentUser?.userId || username?.toLowerCase() == currentUser?.uname?.toLowerCase()) {
          final result = await _validateAndRefresh(
            currentToken,
            currentUser,
          );
          if (result.is200) {
            return result;
          }
        }
      }

      // Not same user - we need to logout from current session
      // Chrome Custom Tab or other external browser might cache
      // the sessions and some IdPs doesn't support that and will
      // show an error message about that to the user. Keycloak
      // is one of those.
      if (currentUser != null) {
        await logout(
          userId: currentUser?.userId,
        );
      }

      // A valid token exists already?
      var actualUser = currentUser;
      if (userId?.isNotEmpty == true) {
        final token = await readToken(userId);
        if (token != null) {
          actualUser = token?.toUser();
          final result = await _validateAndRefresh(
            currentToken,
            currentUser,
          );
          if (result.is200) {
            return result;
          }
        }
      }
      // Select idp hint and prompt values
      final hint = idpHint ?? toIdpHint(username ?? currentUser.uname);
      final idpPrompt = [
        if (_promptValues.containsKey(idpHint)) _promptValues[idpHint],
      ];

      // Request a new session from idp
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          promptValues: idpPrompt,
          // Use actual username if found, otherwise passed username
          loginHint: actualUser?.uname ?? (username.isNotEmpty ? username : null),
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
        lock: true,
      );
    } on PlatformException catch (e, stackTrace) {
      if (USER_ERRORS.contains(e.code)) {
        return ServiceResponse.unauthorized(
          message: "Unauthorized",
        );
      }
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
        stackTrace: stackTrace,
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ServiceResponse<User>> _validateAndRefresh(AuthToken currentToken, User currentUser) {
    if (currentToken?.isExpired == true) {
      return refresh(
        userId: currentUser.userId,
      );
    }
    return _toUser(currentToken, lock: true);
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
          lock: false,
        );
      }
      return super.refresh(
        userId: actualId,
      );
    } on PlatformException catch (e, stackTrace) {
      if (USER_ERRORS.contains(e.code)) {
        return ServiceResponse.unauthorized(
          message: "Unauthorized",
        );
      }
      return ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
        stackTrace: stackTrace,
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete token from secure storage
  @override
  Future<ServiceResponse<User>> logout({
    String userId,
    bool delete: false,
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
        await client.post(url, headers: {
          'Authorization': 'Bearer ${token.body.accessToken}',
        }, body: {
          'client_id': _clientId,
          'refresh_token': token.body.refreshToken,
        });
      }
      return super.logout(
        userId: userId,
        delete: delete,
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to logout",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ServiceResponse<User>> _toUser(AuthToken token, {@required bool lock}) async {
    if (!kReleaseMode) print("Token written: $token");
    final userId = token.userId;
    final security = lock ? await this.lock(userId: userId) : await getSecurity(userId: token.userId);
    return ServiceResponse.ok(
      body: token.toUser(
        security: security.body,
      ),
    );
  }

  Future<AuthToken> _writeToken(TokenResponse response) async {
    final token = await writeToken(
      response.accessToken,
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      accessTokenExpiration: response.accessTokenExpirationDateTime,
    );
    if (!kReleaseMode) print("Token written: $token");
    return token;
  }

  String toIdpHint(String username) {
    final domain = UserService.toDomain(username);
    if (domain != null && _idpHints.containsKey(domain)) {
      return _idpHints[domain];
    }
    return null;
  }
}

class UserCredentialsService extends UserService {
  UserCredentialsService(this.url, this.client, AppConfigBloc bloc) : super(bloc);
  final String url;
  final http.Client client;

  /// Authorize with basic auth and get token
  Future<ServiceResponse<User>> login({
    String userId,
    String username,
    String password,
    String idpHint,
  }) async {
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
          responseObject['token'],
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
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to login",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
