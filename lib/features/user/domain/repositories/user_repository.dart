import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/repositories/auth_token_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:SarSys/features/user/domain/entities/User.dart';

class UserRepository implements Repository<String, User> {
  UserRepository({
    @required this.service,
    @required this.tokens,
    this.compactWhen = 10,
  });

  final int compactWhen;
  final UserService service;
  final AuthTokenRepository tokens;

  /// Get [User.userId] of authenticated user
  String get userId => _userId;
  String _userId;

  /// Get authenticated [user]
  User get user => get(_userId);

  /// Get [ConnectivityService]
  ConnectivityService get connectivity => service.connectivity;

  /// User is online
  bool get isOnline => connectivity.isOnline;

  /// User is offline
  bool get isOffline => connectivity.isOffline;

  /// User is authenticated (token might be invalid)
  bool get isAuthenticated => user != null;

  /// Listen for refresh of token
  Stream<AuthToken> get onRefresh => _controller.stream;
  StreamController<AuthToken> _controller = StreamController.broadcast();

  /// Check if user has token
  User get(String userId) => isReady && _isNotNull(userId) ? _users?.get(userId) : null;
  bool _isNotNull(String userId) => emptyAsNull(userId) != null;

  /// Get [User] from given [User.userId]
  @override
  User operator [](String userId) => get(userId);

  @override
  bool get isEmpty => _users == null || _users.isOpen && _users.isEmpty;

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  int get length => isEmpty ? 0 : _users.length;

  /// Check if user has token
  bool get hasToken => isReady && tokens.containsKey(_userId);

  /// Get token for authenticated [user]
  AuthToken get token => isReady ? tokens[_userId] : null;

  /// Check if token is valid.
  /// If [isOffline] any token
  /// is valid, regardless of
  /// [AuthToken.accessTokenExpiration]
  // ignore: invalid_use_of_protected_member
  bool get isTokenValid => isOffline ? token != null : token?.isValid == true;

  /// Check if token is expired
  // ignore: invalid_use_of_protected_member
  bool get isTokenExpired => isOffline ? false : token?.isExpired == true;

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
      throw RepositoryNotReadyException(this);
    }
  }

  Future<Box<User>> _open() async {
    await tokens.load();
    return Hive.openBox(
      '$UserRepository',
      encryptionCipher: await Storage.hiveCipher<User>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// Load current [user]
  Future<User> load({
    String userId,
    bool refresh = true,
    bool validate = true,
  }) async {
    await _checkState(open: true);

    var actualId = userId ?? _userId;
    if (containsKey(actualId)) {
      final actualToken = await _getToken(
        userId: actualId,
        refresh: refresh,
        validate: validate,
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
          throw UserUnauthorizedException('${actualId ?? username ?? 'unknown'}', this);
        case HttpStatus.forbidden:
          throw UserForbiddenException('${actualId ?? username ?? 'unknown'}', this);
        default:
          throw UserServiceException(
            'Failed to login user ${actualId ?? username ?? 'unknown'}',
            this,
            response: response,
          );
      }
    }
    throw UserRepositoryOfflineException(
      actualId,
      'Unable to login user ${actualId ?? username ?? 'unknown'} in offline mode',
      this,
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
        this,
        response: response,
      );
    }
    throw UserServiceException(
      'Token ${actualId ?? 'unknown'} not found',
      this,
    );
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
        this,
        response: response,
      );
    }
    throw UserServiceException(
      'User ${_userId ?? 'unknown'} not found',
      this,
    );
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
        user.copyWith(security: next),
      );
      return next;
    }
    throw UserNotFoundException(
      actualId,
      this,
    );
  }

  /// Authorize [user] access with given passcodes
  Future<User> authorize(
    Passcodes passcodes, {
    String userId,
    bool locked = true,
  }) async {
    await _checkState();

    final actualId = userId ?? _userId;
    final user = _users.get(actualId);
    if (user != null) {
      return _putUser(
        user.authorize(
          passcodes,
        ),
      );
    }
    throw UserNotFoundException(
      actualId,
      this,
    );
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
      throw UserNotSecuredException(
        userId ?? _userId,
        this,
      );
    }
    throw UserNotFoundException(
      userId ?? _userId,
      this,
    );
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
          await _putUser(user.copyWith(
            security: security,
          ));
          return security;
        }
        throw UserForbiddenException(
          userId ?? _userId,
          this,
        );
      }
      throw UserNotSecuredException(
        userId ?? _userId,
        this,
      );
    }
    throw UserNotFoundException(
      userId ?? _userId,
      this,
    );
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
      // Attempt to refresh token?
      if (refresh) {
        _validateAndRefresh(
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
    throw UserServiceException(
      'Token ${actualId ?? 'unknown'} not found',
      this,
    );
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
    // ignore: invalid_use_of_protected_member
    if (isOnline && (force || token.isExpired)) {
      return _refresh(token, lock: lock);
    }
    return ServiceResponse.ok<User>(
      body: _users.get(token.userId),
    );
  }

  Future<ServiceResponse<User>> _refresh(AuthToken token, {bool lock}) async {
    final response = await service.refresh(token);
    if (response.is200) {
      final token = response.body;
      final user = await _toUser(token, lock: lock);
      _controller.add(token);
      return ServiceResponse.ok<User>(
        body: user,
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
    final next = token.toUser(
      security: security,
    );
    final current = _users.get(next.userId);
    await _putUser(token.toUser(
      security: security,
      passcodes: current?.passcodes ?? const <Passcodes>[],
    ));
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

  void dispose() {
    _controller?.close();
  }
}

class UserNotSecuredException extends RepositoryException {
  UserNotSecuredException(
    this.userId,
    UserRepository repo,
  ) : super('User $userId is not secured', repo);
  final String userId;
}

class UserNotFoundException extends RepositoryException {
  UserNotFoundException(
    this.userId,
    UserRepository repo,
  ) : super('User $userId not found', repo);
  final String userId;
}

class UserUnauthorizedException extends RepositoryException {
  UserUnauthorizedException(
    this.userId,
    UserRepository repo,
  ) : super('User $userId access unauthorized', repo);
  final String userId;

  @override
  String toString() {
    return 'User $userId access unauthorized';
  }
}

class UserRepositoryOfflineException extends RepositoryException {
  UserRepositoryOfflineException(
    this.userId,
    String message,
    UserRepository repo,
  ) : super(message, repo);
  final String userId;
}

class UserForbiddenException extends RepositoryException {
  UserForbiddenException(
    this.userId,
    UserRepository repo,
  ) : super('User $userId access forbidden', repo);
  final String userId;

  @override
  String toString() {
    return 'User $userId access forbidden';
  }
}

class UserServiceException extends RepositoryException {
  UserServiceException(
    Object error,
    UserRepository repo, {
    this.response,
    StackTrace stackTrace,
  }) : super(error, repo, stackTrace: stackTrace);
  final ServiceResponse response;

  @override
  String toString() {
    return 'UserServiceException: $message, response: $response, stackTrace: $stackTrace';
  }
}
