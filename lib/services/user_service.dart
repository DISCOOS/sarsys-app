import 'dart:convert';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:jose/jose.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

abstract class UserService {
  // TODO: Take into account that several users may use the app and handle token storage accordingly

  static final storage = new FlutterSecureStorage();

  Future<ServiceResponse<AuthToken>> authorize({String username, String password});

  Future<ServiceResponse<AuthToken>> refresh() async {
    return ServiceResponse.noContent<AuthToken>();
  }

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

  Future<ServiceResponse<Security>> getSecurity() async {
    try {
      final json = await storage.read(key: "security");
      if (json != null) {
        return ServiceResponse.ok(
          body: Security.fromJson(jsonDecode(json)),
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

  Future<ServiceResponse<Security>> secure(Security security) async {
    try {
      var next;
      final response = await getSecurity();
      if (response.is200) {
        next = response.body.cloneWith(
          pin: security.pin,
          type: security.type,
          locked: security.locked,
          paused: security.paused,
        );
      } else {
        next = security;
      }
      await storage.write(
        key: "security",
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
      return ServiceResponse.internalServerError(error: e);
    }
  }

  /// Get current user from resource owner
  Future<ServiceResponse<User>> load() async {
    final result = await getToken();
    if (result.is200) {
      return ServiceResponse.ok(body: result.body.asUser());
    }
    return ServiceResponse.noContent();
  }

  /// Get current token from secure storage
  Future<ServiceResponse<AuthToken>> getToken() async {
    try {
      final token = await read();
      if (token != null) {
        var jwt = JsonWebToken.unverified(token.accessToken);
        if (!kReleaseMode) print("Token found: $token");
        if (jwt.claims.expiry.isAfter(DateTime.now())) {
          if (!kReleaseMode) print("Token still valid");
          return ServiceResponse.ok(body: token);
        }
        return refresh();
      }
    } on FormatException {
      await logout();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(error: e);
    }
    return ServiceResponse.noContent();
  }

  /// Delete token from secure storage
  Future<ServiceResponse<Security>> logout() async {
    try {
      // Delete token from storage
      await storage.delete(key: 'token');
      final result = await getSecurity();
      return ServiceResponse.ok(body: result.body);
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to delete token from storage",
        error: e,
      );
    }
  }

  Future<AuthToken> read() async {
    final json = await storage.read(key: "token");
    return json == null ? null : AuthToken.fromJson(jsonDecode(json));
  }

  @protected
  Future<AuthToken> write({
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
    await UserService.storage.write(
      key: "token",
      value: jsonEncode(token.toJson()),
    );
    return token;
  }
}

class UserIdentityService extends UserService {
  UserIdentityService(this.client);
  final Client client;

  static const String AUTHORIZE_ERROR_CODE = "authorize_failed";
  static const String TOKEN_ERROR_CODE = "token_failed";
  static const List<String> USER_ERRORS = const [AUTHORIZE_ERROR_CODE, TOKEN_ERROR_CODE];

  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final String _clientId = 'sarsys-web';
  final String _redirectUrl = 'sarsys.app://oauth/redirect';
  final String _logoutUrl = 'https://id.discoos.io/auth/realms/DISCOOS/protocol/openid-connect/logout';
  final String _discoveryUrl = 'https://id.discoos.io/auth/realms/DISCOOS/.well-known/openid-configuration';
  final List<String> _scopes = const ['openid', 'profile', 'email', 'offline_access', 'roles'];
  final List<String> _idpHints = const ['rodekors'];

  /// Authorize and get token
  @override
  Future<ServiceResponse<AuthToken>> authorize({String username, String password}) async {
    try {
      final idpHint = _toIdpHint(username);
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          loginHint: username,
          promptValues: [
            'login', // Force login
          ],
          additionalParameters: {
            if (idpHint != null) 'kc_idp_hint': idpHint,
          },
          discoveryUrl: _discoveryUrl,
        ),
      );
      return await _writeToken(
        response,
      );
    } on PlatformException catch (e) {
      if (USER_ERRORS.contains(e.code)) {
        if (e.message.contains('User cancelled flow')) {
          return ServiceResponse.noContent(
            message: "Cancelled by user",
          );
        }
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
  Future<ServiceResponse<AuthToken>> refresh() async {
    try {
      final current = await this.read();
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
        return await _writeToken(
          response,
        );
      }
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
    return super.refresh();
  }

  /// Delete token from secure storage
  @override
  Future<ServiceResponse<Security>> logout() async {
    try {
      final token = await getToken();
      if (token.is200) {
        final response = await client.post(_logoutUrl, headers: {
          'Authorization': 'Bearer ${token.body.accessToken}',
        }, body: {
          'client_id': _clientId,
          'refresh_token': token.body.refreshToken,
        });
        return super.logout();
      }
      return ServiceResponse.noContent();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(
        message: "Failed to delete token from storage",
        error: e,
      );
    }
  }

  Future<ServiceResponse<AuthToken>> _writeToken(TokenResponse response) async {
    final token = await write(
      idToken: response.idToken,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpiration: response.accessTokenExpirationDateTime,
    );
    if (!kReleaseMode) print("Token written: $token");
    return ServiceResponse.ok(
      body: token,
    );
  }

  String _toIdpHint(String username) {
    final pattern = RegExp(".*.@(\\w+)\..*");
    final matcher = pattern.firstMatch(username);
    if (matcher != null && _idpHints.contains(matcher.group(1))) {
      return matcher.group(1);
    }
    return null;
  }
}

class UserCredentialsService extends UserService {
  UserCredentialsService(this.url, this.client);
  final String url;
  final Client client;

  /// Authorize with basic auth and get token
  Future<ServiceResponse<AuthToken>> authorize({String username, String password}) async {
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
        final token = await write(accessToken: responseObject['token']);
        return ServiceResponse.ok(
          body: token,
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
