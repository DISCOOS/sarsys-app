import 'dart:async';
import 'dart:convert';

import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

abstract class UserService {
  /// Get domain from username
  static String toDomain(String username) {
    final pattern = RegExp(".*.@(.*)");
    final matcher = pattern.firstMatch(username);
    return matcher?.group(1);
  }

  /// Authorize and get token
  Future<ServiceResponse<AuthToken>> login({
    String userId,
    String username,
    String password,
    String idpHint,
  });

  /// Refresh token
  Future<ServiceResponse<AuthToken>> refresh(AuthToken token);

  /// Logout from session
  Future<ServiceResponse<void>> logout(AuthToken token);
}

class UserIdentityService extends UserService {
  UserIdentityService(this.client);
  final http.Client client;

  static const String AUTHORIZE_ERROR_CODE = "authorize_failed";
  static const String TOKEN_ERROR_CODE = "token_failed";
  static const String AUTHORIZE_AND_EXCHANGE_CODE_FAILED = 'authorize_and_exchange_code_failed';
  static const List<String> USER_ERRORS = const [
    AUTHORIZE_ERROR_CODE,
    TOKEN_ERROR_CODE,
    AUTHORIZE_AND_EXCHANGE_CODE_FAILED,
  ];
  static const String REFRESH_URL = 'https://id.discoos.io/auth/realms/DISCOOS/protocol/openid-connect/token';

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
  Future<ServiceResponse<AuthToken>> login({
    String userId,
    String username,
    String password,
    String idpHint,
  }) async {
    try {
      // Select idp hint and prompt values
      final hint = idpHint ?? toIdpHint(username);
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
          loginHint: emptyAsNull(username),
          additionalParameters: {
            if (hint != null) 'kc_idp_hint': hint,
          },
          discoveryUrl: _discoveryUrl,
        ),
      );

      // Write token and get user
      return ServiceResponse.ok<AuthToken>(
        body: AuthToken(
          clientId: _clientId,
          idToken: response.idToken,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          accessTokenExpiration: response.accessTokenExpirationDateTime,
        ),
      );
    } on PlatformException catch (e, stackTrace) {
      if (USER_ERRORS.contains(e.code)) {
        return ServiceResponse.unauthorized(
          message: "Unauthorized",
          error: e,
        );
      }
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
        message: "Failed to login",
      );
    } catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
        message: "Failed to login",
      );
    }
  }

  Completer<ServiceResponse<AuthToken>> _refreshCompleter;

  @override
  Future<ServiceResponse<AuthToken>> refresh(AuthToken token) async {
    // Refresh is pending?
    if (_refreshCompleter != null && _refreshCompleter.isCompleted == false) {
      return _refreshCompleter.future;
    }
    _refreshCompleter = Completer<ServiceResponse<AuthToken>>();
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUrl,
          scopes: _scopes,
          discoveryUrl: _discoveryUrl,
          refreshToken: token.refreshToken,
        ),
      );
      _refreshCompleter.complete(ServiceResponse.ok<AuthToken>(
        body: AuthToken(
          clientId: _clientId,
          idToken: response.idToken,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          accessTokenExpiration: response.accessTokenExpirationDateTime,
        ),
      ));
    } on PlatformException catch (e, stackTrace) {
      if (USER_ERRORS.contains(e.code)) {
        _refreshCompleter.complete(ServiceResponse.unauthorized(
          message: "Unauthorized",
          error: e,
        ));
      }
      _refreshCompleter.complete(ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
        stackTrace: stackTrace,
      ));
    } catch (e, stackTrace) {
      _refreshCompleter.complete(ServiceResponse.internalServerError(
        message: "Failed to refresh token",
        error: e,
        stackTrace: stackTrace,
      ));
    }
    return _refreshCompleter.future;
  }

  /// Delete token from secure storage
  @override
  Future<ServiceResponse<void>> logout(AuthToken token) async {
    try {
      // Chrome Custom Tab or other external browsers used by
      // AppAuth will cache the session. Some IdPs doesn't support
      // multiple session and will complain that a user is already
      // logged in. Keycloak is one of those. This problems is
      // resolved by actively invalidating the session using the
      // openid connect logout endpoint.
      //
      final url = '$_logoutUrl?redirect_uri=$_redirectUrl';
      await client.post(
        url,
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
        },
        body: {
          'client_id': _clientId,
          'refresh_token': token.refreshToken,
        },
      );
      return ServiceResponse.noContent();
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        message: "Failed to logout with token $token",
        error: e,
        stackTrace: stackTrace,
      );
    }
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
  UserCredentialsService(this.url, this.client);
  final String url;
  final http.Client client;

  /// Authorize with basic auth and get token
  Future<ServiceResponse<AuthToken>> login({
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
        return ServiceResponse.ok(
          body: AuthToken.fromJson(
            responseObject['token'],
          ),
        );
      } else if (response.statusCode == 401) {
        return ServiceResponse.unauthorized(error: response);
      } else if (response.statusCode == 403) {
        return ServiceResponse.forbidden();
      }
      return ServiceResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
      );
    } on Exception catch (e, stackTrace) {
      return ServiceResponse.internalServerError(
        error: e,
        stackTrace: stackTrace,
        message: "Failed to login",
      );
    }
  }

  @override
  Future<ServiceResponse<void>> logout(AuthToken token) async {
    return ServiceResponse.badRequest<void>();
  }

  @override
  Future<ServiceResponse<AuthToken>> refresh(AuthToken token) async {
    return ServiceResponse.badRequest<void>();
  }
}
