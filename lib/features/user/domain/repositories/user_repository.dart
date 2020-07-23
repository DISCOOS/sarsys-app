import 'dart:io';

import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/repositories/auth_token_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:SarSys/features/user/domain/entities/User.dart';

class UserRepository implements Repository {
  UserRepository({
    @required this.service,
    @required this.tokens,
    @required this.connectivity,
    this.compactWhen = 10,
  });
  final int compactWhen;
  final UserService service;
  final AuthTokenRepository tokens;
  final ConnectivityService connectivity;

  String _userId;
  String get userId => _userId;

  /// Get authenticated [user]
  User get user => get(_userId);

  /// User is online
  bool get isOnline => connectivity.isOnline;

  /// User is offline
  bool get isOffline => connectivity.isOffline;

  /// User is authenticated (token might be invalid)
  bool get isAuthenticated => user != null;

  /// Check if user has token
  User get(String userId) => isReady && _isNotNull(userId) ? _users?.get(userId) : null;
  bool _isNotNull(String userId) => emptyAsNull(userId) != null;

  /// Get [User] from given [User.userId]
  User operator [](String userId) => get(userId);

  /// Check if user has token
  bool get hasToken => isReady && tokens.containsKey(_userId);

  /// Get token for authenticated [user]
  AuthToken get token => isReady ? tokens[_userId] : null;

  /// Check if token is valid
  bool get isTokenValid => token?.isValid == true;

  /// Check if token is expired
  bool get isTokenExpired => token?.isExpired == true;

  /// Get all cached [User.userId]s
  Iterable<String> get keys => isReady && _users != null ? List.unmodifiable(_users.keys) : null;

  /// Get all cached [User]s
  Iterable<User> get values => isReady && _users != null ? List.unmodifiable(_users.values) : null;

  /// Check if user with [userId] is cached
  bool containsKey(String userId) => !isReady ? false : (_users?.keys?.contains(userId) ?? false);

  /// Check if given [user] is cached
  bool containsValue(User user) => !isReady ? false : (_users?.values?.contains(user) ?? false);

  /// Check if repository is ready
  bool get isReady => _users?.isOpen == true;

  /// Check if local access to user data is secured
  bool isSecured({String userId}) => _users.get(userId ?? _userId)?.security != null;

  Box<User> _users;
  Future _checkState({bool open = false}) async {
    if (open) {
      _users ??= await _open();
      _userId = await Storage.readUserId();
    } else if (!isReady) {
      throw UserRepositoryNotReadyException();
    }
  }

  Future<Box<User>> _open() async {
    await tokens.load();
    return Hive.openBox(
      '$UserRepository',
      encryptionKey: await Storage.hiveKey<User>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// Load current [user]
  Future<User> load({
    String userId,
    bool validate = true,
    bool refresh = true,
  }) async {
    await _checkState(open: true);

    var actualId = userId ?? _userId;
    if (containsKey(actualId)) {
      final actualToken = await _getToken(
        userId: actualId,
        validate: validate,
        refresh: refresh,
      );
      await _putToken(
        actualToken,
        security: user?.security,
      );
      actualId = _userId;
    }
    return get(actualId);
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
    final actualToken = tokens[actualId];
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
    if (_shouldValidateAndRefresh(actualToken, actualId)) {
      final response = await _validateAndRefresh(
        actualToken,
        lock: true,
      );
      if (response.is200) {
        return response.body;
      }
    }

    // No existing tokens found
    if (isOnline) {
      final response = await service.login(
        userId: actualId,
        username: username,
        password: password,
        idpHint: idpHint,
      );
      switch (response.statusCode) {
        case HttpStatus.ok:
          return await _toUser(
            response.body,
            lock: isSecured(userId: response.body.userId),
          );
        case HttpStatus.unauthorized:
          throw UserUnauthorizedException('${actualId ?? username ?? 'unknown'}');
        case HttpStatus.forbidden:
          throw UserForbiddenException('${actualId ?? username ?? 'unknown'}');
        default:
          throw UserServiceException(
            'Failed to login user ${actualId ?? username ?? 'unknown'}',
            response: response,
          );
      }
    }
    throw UserRepositoryOfflineException(
      actualId,
      'Unable to login user ${actualId ?? username ?? 'unknown'} in offline mode',
    );
  }

  bool _shouldValidateAndRefresh(AuthToken actualToken, String actualId) =>
      actualToken != null && actualId != null && actualId != _userId;

  /// Refresh [AuthToken]
  Future<User> refresh({String userId}) async {
    await _checkState();

    final actualId = userId ?? _userId;
    final actualToken = tokens[actualId];
    if (actualToken != null) {
      final response = await _validateAndRefresh(
        actualToken,
        lock: false,
        force: true,
      );
      if (response.is200) {
        return response.body;
      }
      throw UserServiceException(
        'Failed to refresh token for user ${actualId ?? 'unknown'}',
        response: response,
      );
    }
    throw AuthTokenNotFoundException('${actualId ?? 'unknown'}');
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
        if (SecurityMode.shared == actualUser?.security?.mode) {
          await lock(
            userId: actualUserId,
          );
        }
        await _delete(
          actualUserId,
          // Always delete untrusted users
          user: delete || actualUser.isUntrusted,
        );
        return actualUser;
      }
      throw UserServiceException(
        'Failed to logout user ${actualUserId ?? 'unknown'}',
        response: response,
      );
    }
    throw AuthTokenNotFoundException(userId ?? _userId ?? 'unknown');
  }

  /// Clear all users
  Future<Iterable<User>> clear() async {
    await _checkState();
    final users = _users.values.toList();
    await _users.clear();
    await tokens.clear();
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
    final user = _users.get(actualId);
    if (user != null) {
      var next;
      if (user.security != null) {
        next = user.security.cloneWith(
          pin: pin,
          locked: locked,
          trusted: trusted ?? false,
          type: type,
          mode: mode,
          heartbeat: DateTime.now(),
        );
      } else {
        next = Security(
          pin: pin,
          locked: locked ?? true,
          trusted: trusted ?? false,
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
  Future<Security> unlock(String pin) async {
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
    final actualToken = tokens[actualId];
    if (actualToken != null) {
      bool isValid = actualToken.isValid;
      if (isValid || !validate) {
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
      final token = tokens[actualId];
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
    // Skip when offline allowing authenticated
    // user to remain authenticated regardless
    // off connectivity status. Including opening
    // the app again without being forced to
    // refresh or authenticate, which would make
    // the app unusable during a network partition
    if (isOnline && (force || token.isExpired)) {
      return await _refresh(token, lock: lock);
    }
    return ServiceResponse.ok<User>(
      body: _users.get(token.userId),
    );
  }

  Future<ServiceResponse<User>> _refresh(AuthToken token, {bool lock}) async {
    final response = await service.refresh(token);
    if (response.is200) {
      final token = response.body;
      return ServiceResponse.ok<User>(
        body: await _toUser(token, lock: lock),
      );
    }
    return response.copyWith<User>(
      body: _users.get(token.userId),
    );
  }

  Future<User> _toUser(AuthToken token, {@required bool lock}) async {
    final userId = token.userId;
    final security = _users.get(userId)?.security;
    await _putToken(
      token,
      security: lock ? security?.cloneWith(locked: true) : security,
    );
    return _users.get(userId);
  }

  Future<AuthToken> _delete(
    String userId, {
    bool user: false,
  }) async {
    final token = await tokens.delete(
      userId,
    );
    if (user) {
      await _users.delete(userId);
    }
    await _unset(userId);
    return token;
  }

  Future<AuthToken> _putToken(AuthToken token, {Security security}) async {
    await tokens.put(token);
    await _putUser(token.toUser(security: security));
    return token;
  }

  Future<User> _putUser(User user) async {
    _userId = user.userId;
    await _users.put(user.userId, user);
    await Storage.writeUserId(_userId);
    return user;
  }

  Future _unset(String userId) async {
    if (userId == _userId) {
      _userId = null;
      await Storage.deleteUserId();
    }
    return Future.value();
  }
}

class UserNotSecuredException extends RepositoryException {
  UserNotSecuredException(this.userId) : super('User $userId is not secured');
  final String userId;
}

class UserNotFoundException extends RepositoryException {
  UserNotFoundException(this.userId) : super('User $userId not found');
  final String userId;
}

class UserUnauthorizedException extends RepositoryException {
  UserUnauthorizedException(this.userId) : super('User $userId access unauthorized');
  final String userId;

  @override
  String toString() {
    return 'User $userId access unauthorized';
  }
}

class UserRepositoryOfflineException extends RepositoryException {
  UserRepositoryOfflineException(this.userId, String message) : super(message);
  final String userId;
}

class UserForbiddenException extends RepositoryException {
  UserForbiddenException(this.userId) : super('User $userId access forbidden');
  final String userId;

  @override
  String toString() {
    return 'User $userId access forbidden';
  }
}

class UserServiceException extends RepositoryException {
  UserServiceException(
    Object error, {
    this.response,
    StackTrace stackTrace,
  }) : super(error, stackTrace: stackTrace);
  final ServiceResponse response;

  @override
  String toString() {
    return 'UserServiceException: $message, response: $response, stackTrace: $stackTrace';
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

class UserRepositoryNotReadyException extends RepositoryNotReadyException {
  UserRepositoryNotReadyException();
}
