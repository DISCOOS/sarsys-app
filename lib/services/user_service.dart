import 'dart:convert';

import 'package:SarSys/models/AuthToken.dart';
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

  Future<ServiceResponse<AuthToken>> login({String username, String password});

  Future<ServiceResponse<AuthToken>> refresh() async {
    return ServiceResponse.noContent<AuthToken>();
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
      return logout();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(error: e);
    }
    return ServiceResponse.noContent();
  }

  /// Delete token from secure storage
  Future<ServiceResponse<void>> logout() async {
    try {
      // Delete token from storage
      await storage.delete(key: 'token');
      return ServiceResponse.noContent();
    } on Exception catch (e) {
      return ServiceResponse.internalServerError(message: "Failed to delete token from storage", error: e);
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
  UserIdentityService();

  static const String AUTHORIZE_ERROR_CODE = "authorize_failed";
  static const String TOKEN_ERROR_CODE = "token_failed";
  static const List<String> USER_ERRORS = const [AUTHORIZE_ERROR_CODE, TOKEN_ERROR_CODE];

  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final String _clientId = 'sarsys-web';
  final String _redirectUrl = 'sarsys.app://oauth/redirect';
  final String _discoveryUrl = 'https://id.discoos.io/auth/realms/DISCOOS/.well-known/openid-configuration';
  final List<String> _scopes = <String>['openid', 'profile', 'email', 'offline_access', 'roles'];

  /// Authorize and get token
  @override
  Future<ServiceResponse<AuthToken>> login({String username, String password}) async {
    try {
      final access = await _appAuth.authorize(
        AuthorizationRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          loginHint: username,
          discoveryUrl: _discoveryUrl,
        ),
      );
      return await _fetchToken(
        TokenRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          discoveryUrl: _discoveryUrl,
          codeVerifier: access.codeVerifier,
          authorizationCode: access.authorizationCode,
        ),
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
        final next = await _fetchToken(
          TokenRequest(
            _clientId,
            _redirectUrl,
            scopes: _scopes,
            discoveryUrl: _discoveryUrl,
            refreshToken: current.refreshToken,
          ),
        );
        if (!kReleaseMode) print("Token refreshed: $next");
        return next;
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

  Future<ServiceResponse<AuthToken>> _fetchToken(TokenRequest request) async {
    final result = await _appAuth.token(
      request,
    );

    final token = await write(
      idToken: result.idToken,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      accessTokenExpiration: result.accessTokenExpirationDateTime,
    );

    return ServiceResponse.ok(
      body: token,
    );
  }
}

class UserCredentialsService extends UserService {
  final String url;
  final Client client;

  UserCredentialsService(this.url, this.client);

  /// Authorize with basic auth and get token
  Future<ServiceResponse<AuthToken>> login({String username, String password}) async {
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
      return ServiceResponse.internalServerError(message: "Failed to login", error: e);
    }
  }
}
