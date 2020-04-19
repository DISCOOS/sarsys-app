import 'dart:io';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/repositories/auth_token_repository.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:SarSys/models/User.dart';

class UserRepository {
  UserRepository(
    this.service, {
    this.compactWhen = 10,
  });
  final int compactWhen;
  final UserService service;
  final AuthTokenRepository _tokens = AuthTokenRepository();

  String _userId;
  String get userId => _userId;

  User get user => _users?.get(_userId);

  AuthToken get token => _tokens[_userId];
  bool get isTokenValid => token?.isValid == true;
  bool get hasToken => _tokens.containsKey(_userId);

  Iterable<String> get keys => _users != null ? List.unmodifiable(_users.toMap().keys) : null;
  Iterable<User> get values => _users != null ? List.unmodifiable(_users.toMap().values) : null;

  bool containsKey(String userId) => _users?.keys?.contains(userId) ?? false;
  bool containsValue(User user) => _users?.values?.contains(user) ?? false;

  Box<User> _users;

  Future _checkState({bool open = false}) async {
    if (open) {
      _users ??= await _open();
    } else if (!isReady) {
      throw UserRepositoryNotReadyException();
    }
  }

  /// Check if repository is ready
  bool get isReady => _users?.isOpen == true && _users.containsKey(_userId);

  /// Check if local access to user data is secured
  bool isSecured({String userId}) => _users.get(userId ?? _userId) != null;

  Future<Box<User>> _open() async {
    _tokens.load();
    return Hive.openBox(
      '$UserRepository',
      encryptionKey: await Storage.hiveKey<User>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// Load [user]
  Future<User> load({
    String userId,
    bool validate = true,
    bool refresh = true,
  }) async {
    await _checkState(open: true);

    final actualId = userId ?? _userId;
    if (containsKey(actualId)) {
      final actualToken = await _getToken(
        userId: actualId,
        validate: validate,
        refresh: refresh,
      );
      return await _putUser(
        actualToken.toUser(
          security: user?.security,
        ),
      );
    }
    throw UserNotFoundException(actualId);
  }

  /// Authenticate [user]
  Future<User> login({
    String userId,
    String username,
    String password,
    String idpHint,
  }) async {
    await _checkState(open: true);

    final actualId = userId ?? _userId;
    final actualToken = _tokens[actualId];
    if (hasToken) {
      if (actualId == _userId) {
        // Login request is for current user
        final response = await _validateAndRefresh(
          actualToken,
          lock: true,
        );
        if (response.is200) {
          return response.body;
        }
      }
      // We need to logout from current session
      // Chrome Custom Tab or other external browser might cache
      // the sessions and some IdPs doesn't support that and will
      // show an error message to users. Keycloak is one of those.
      await logout();
    }

    // Is login request for user with an old token?
    if (actualToken?.userId != _userId) {
      final response = await _validateAndRefresh(
        actualToken,
        lock: true,
      );
      if (response.is200) {
        return response.body;
      }
    }

    // No existing tokens found
    final response = await service.login(
      userId: actualId,
      username: username,
      password: password,
      idpHint: idpHint,
    );
    switch (response.code) {
      case HttpStatus.ok:
        return await _toUser(
          response.body,
          lock: true,
        );
      case HttpStatus.unauthorized:
        throw UserUnauthorizedException(actualId);
      case HttpStatus.forbidden:
        throw UserForbiddenException(actualId);
      default:
        throw UserServiceException(
          'Failed to login user $actualId',
          response: response,
        );
    }
  }

  /// Refresh [AuthToken]
  Future<User> refresh({String userId}) async {
    await _checkState();

    final actualId = userId ?? _userId;
    final actualToken = _tokens[actualId];
    if (actualToken != null) {
      final response = await _validateAndRefresh(
        actualToken,
        lock: false,
        force: true,
      );
      if (response.is200) {
        return _putUser(
          response.body,
        );
      }
      throw UserServiceException(
        'Failed to refresh token for user $actualId',
        response: response,
      );
    }
    throw AuthTokenNotFoundException(actualId);
  }

  /// Logout user
  Future<User> logout({
    String userId,
    bool delete = false,
  }) async {
    await _checkState();

    // Get a valid token
    final actualToken = await _getToken(
      userId: userId,
    );
    if (actualToken != null) {
      final actualUserId = actualToken.userId;
      final response = await service.logout(
        actualToken,
      );
      if (response.is204) {
        final actualUser = _users.get(actualUserId);
        // In shared mode users must be locked to prevent accidental logins
        if (SecurityMode.shared == actualUser.security.mode) {
          await lock(
            userId: actualUserId,
          );
        }
        await _delete(
          actualUserId,
          // Always delete untrusted users
          user: delete || actualUser.isUntrusted,
        );
        if (!kReleaseMode) {
          print("Logged out user $actualUserId");
        }
        return actualUser;
      }
      throw UserServiceException(
        'Failed to logout user $actualUserId',
        response: response,
      );
    }
    throw AuthTokenNotFoundException(userId ?? _userId);
  }

  /// Clear all users
  Future<Iterable<User>> clear() async {
    await _checkState();
    final users = _users.values.toList();
    await _users.clear();
    await _tokens.clear();
    return users;
  }

  /// Secure [user] access with given pin
  Future<Security> secure(
    String pin, {
    @required bool trusted,
    @required SecurityType type,
    @required SecurityMode mode,
    String userId,
    bool locked = true,
  }) async {
    await _checkState();

    final actualId = userId ?? _userId;
    final user = _users.get(userId);
    if (user != null) {
      var next;
      if (user.security != null) {
        next = user.security.cloneWith(
          pin: pin,
          locked: locked,
          trusted: trusted,
          type: type,
          mode: mode,
          heartbeat: DateTime.now(),
        );
      } else {
        next = Security(
          pin: pin,
          locked: locked,
          trusted: trusted,
          type: type,
          mode: mode,
          heartbeat: DateTime.now(),
        );
      }
      await _putUser(
        user.cloneWith(security: next),
      );
      return next;
    }
    throw UserNotFoundException(actualId);
  }

  /// Lock [user] access
  Future<Security> lock({String userId}) async {
    await _checkState();

    final user = _users.get(userId ?? _userId);
    if (user != null) {
      final security = user.security;
      if (security?.pin != null)
        return secure(
          user.security.pin,
          locked: true,
          userId: user.userId,
          type: security.type,
          mode: security.mode,
          trusted: security.trusted,
        );
      throw UserNotSecuredException(userId ?? _userId);
    }
    throw UserNotFoundException(userId ?? _userId);
  }

  /// Unlock [user] access with given pin
  Future<Security> unlock({String pin}) async {
    await _checkState();

    final user = _users.get(userId ?? _userId);
    if (user != null) {
      var security = user.security;
      if (security != null) {
        if (security.locked == false || security.pin == pin) {
          security = security.cloneWith(
            locked: false,
            type: security.type,
            mode: security.mode,
            trusted: security.trusted,
            heartbeat: DateTime.now(),
          );
          await _putUser(user.cloneWith(
            security: security,
          ));
          return security;
        }
        throw UserForbiddenException(userId ?? _userId);
      }
      throw UserNotSecuredException(userId ?? _userId);
    }
    throw UserNotFoundException(userId ?? _userId);
  }

  /// Get current token from secure storage
  Future<AuthToken> _getToken({
    String userId,
    bool refresh = true,
    bool validate = true,
  }) async {
    final actualId = userId ?? _userId;
    final actualToken = _tokens[actualId];
    if (actualToken != null) {
      if (kDebugMode) print("Token found for $actualId: $actualToken");
      bool isValid = actualToken.isValid;
      if (isValid || !validate) {
        if (kDebugMode) {
          print("Token ${isValid ? 'still' : 'is not'} valid");
        }
        return actualToken;
      }
      // Refresh token?
      if (refresh) {
        await _validateAndRefresh(
          actualToken,
          lock: false,
        );
      }
      // Get refreshed token
      final token = _tokens[actualId];
      if (token != null) {
        return token;
      }
    }
    throw AuthTokenNotFoundException(actualId);
  }

  Future<ServiceResponse<User>> _validateAndRefresh(
    AuthToken token, {
    bool lock = true,
    bool force = false,
  }) async {
    if (force || token.isExpired) {
      final response = await _refresh(token);
      if (response.is200) {
        return ServiceResponse.ok<User>(
          body: await _toUser(
            token,
            lock: lock,
          ),
        );
      }
    }
    return ServiceResponse.ok<User>(
      body: _users.get(token.userId),
    );
  }

  Future<ServiceResponse<AuthToken>> _refresh(AuthToken token) async {
    final response = await service.refresh(token);
    if (response.is200) {
      return ServiceResponse.ok<AuthToken>(
        body: await _putToken(response.body),
      );
    }
    return response;
  }

  Future<User> _toUser(AuthToken token, {@required bool lock}) async {
    final userId = token.userId;
    final security = lock ? await this.lock(userId: userId) : _users.get(userId).security;
    return _putUser(
      token.toUser(
        security: security,
      ),
    );
  }

  Future<AuthToken> _delete(
    String userId, {
    bool user: false,
  }) async {
    final token = await _tokens.delete(
      userId,
    );
    if (user) {
      await _users.delete(userId);
    }
    _unset(userId);
    return token;
  }

  Future<AuthToken> _putToken(AuthToken token) async {
    if (kDebugMode) {
      print("Token written: $token");
    }
    await _tokens.put(token);
    return token;
  }

  Future<User> _putUser(User user, {bool current = true}) async {
    if (current) {
      _userId = user.userId;
    }
    await _users.put(user.userId, user);
    return user;
  }

  void _unset(String userId) {
    if (userId == _userId) {
      _userId = null;
    }
  }
}

class UserNotSecuredException implements Exception {
  UserNotSecuredException(this.userId);
  final String userId;

  @override
  String toString() {
    return 'User $userId is not secured';
  }
}

class UserNotFoundException implements Exception {
  UserNotFoundException(this.userId);
  final String userId;

  @override
  String toString() {
    return 'User $userId not found';
  }
}

class UserUnauthorizedException implements Exception {
  UserUnauthorizedException(this.userId);
  final String userId;

  @override
  String toString() {
    return 'User $userId access unauthorized';
  }
}

class UserForbiddenException implements Exception {
  UserForbiddenException(this.userId);
  final String userId;

  @override
  String toString() {
    return 'User $userId access forbidden';
  }
}

class UserServiceException implements Exception {
  UserServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'UserServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}

class AuthTokenNotFoundException implements Exception {
  AuthTokenNotFoundException(this.userId);
  final String userId;

  @override
  String toString() {
    return 'AuthToken for User $userId not found';
  }
}

class UserRepositoryNotReadyException implements Exception {
  UserRepositoryNotReadyException();
  @override
  String toString() {
    return 'UserRepository is not ready';
  }
}
