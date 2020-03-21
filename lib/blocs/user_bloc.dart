import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter/foundation.dart' show VoidCallback;

typedef void UserCallback(VoidCallback fn);

class UserBloc extends Bloc<UserCommand, UserState> {
  final UserService service;
  final LinkedHashMap<String, UserAuthorized> _authorized = LinkedHashMap();

  UserBloc(this.service);

  @override
  get initialState => UserUnset();

  /// Get user
  User get user => _user;
  User _user;

  /// Get security
  Security get security => _security;
  Security _security;

  /// User identity is secured
  bool get isSecured => _security != null;

  /// User access is locked. This should enforce login
  bool get isLocked => !isSecured || _security.locked == true;

  /// User access is unlocked
  bool get isUnlocked => _security?.locked == false;

  /// User identity is secured
  bool get isAuthenticated => _user != null;

  /// User identity is ready to be accessed. If false, login should be enforced
  bool get isReady => isSecured && isUnlocked && isAuthenticated;

  /// Check if current user is authorized to access given [Incident]
  bool isAuthorized(Incident data) {
    return isAuthenticated && (_authorized.containsKey(data.id) || _user?.userId == data.created.userId);
  }

  /// Check if current user is authorized to access given [Incident]
  UserAuthorized getAuthorization(Incident data) {
    if (isAuthenticated) {
      if (_authorized.containsKey(data.id)) return _authorized[data.id];
      if (_user?.userId == data.created.userId) return UserAuthorized(_user, data, true, true);
    }
    return null;
  }

  /// Stream of authorization state changes
  Stream<bool> authorized(Incident incident) =>
      state.map((state) => state is UserAuthorized && state.incident == incident);

  /// Secure user access with given settings
  Future<Security> secure(Security security) async {
    return _dispatch<Security>(SecureUser(security));
  }

  /// Lock user access using current security settings
  Future<dynamic> lock() async {
    return _dispatch<dynamic>(LockUser());
  }

  /// Unlock user access
  Future<dynamic> unlock({String pin}) async {
    return _dispatch<dynamic>(_assertLocked(UnlockUser(pin: pin)));
  }

  UserCommand _assertLocked(UserCommand command) {
    return isUnlocked ? RaiseUserError.from("Er låst opp") : command;
  }

  /// Load user from secure storage
  Future<User> load() async {
    return _dispatch<User>(_assertUnset(LoadUser()));
  }

  Future<User> authenticate({String username, String password}) {
    return _dispatch<User>(_assertUnset(AuthenticateUser(username, password)));
  }

  UserCommand _assertUnset(UserCommand command) {
    return isAuthenticated ? RaiseUserError.from("Er logget inn") : command;
  }

  Future<bool> logout() {
    return _dispatch<bool>(LogoutUser());
  }

  UserCommand _assertAuthenticated(UserCommand command) {
    return isAuthenticated ? command : RaiseUserError.from("Ikke logget inn");
  }

  Future<bool> authorize(Incident data, String passcode) {
    return _dispatch<bool>(_assertAuthenticated(AuthorizeUser(data, passcode)));
  }

  @override
  Stream<UserState> mapEventToState(UserCommand command) async* {
    try {
      if (command is SecureUser) {
        yield await _secure(command);
      } else if (command is LockUser) {
        yield await _lock(command);
      } else if (command is UnlockUser) {
        yield UserUnlocking(command.data);
        yield await _unlock(command);
      } else if (command is LoadUser) {
        yield await _load(command);
      } else if (command is AuthenticateUser) {
        yield UserAuthenticating(command.data);
        yield await _authenticate(command);
      } else if (command is LogoutUser) {
        yield await _logout(command);
      } else if (command is AuthorizeUser) {
        if (_user != null) {
          yield _authorize(command);
        }
      } else if (command is RaiseUserError) {
        yield _toError(command, command.data);
      } else {
        yield UserError("Unsupported $command");
      }
    } catch (e) {
      _toError(command, e);
    }
  }

  Future<UserState> _secure(SecureUser command) async {
    var response = await service.secure(command.data);
    return _toSecurityEvent(response, command);
  }

  Future<UserState> _lock(LockUser command) async {
    var response = await service.lock();
    return _toSecurityEvent(response, command);
  }

  Future<UserState> _unlock(UnlockUser command) async {
    var response = await service.unlock(pin: command.data);
    return _toSecurityEvent(response, command);
  }

  UserState _toSecurityEvent(ServiceResponse<Security> response, UserCommand command) {
    switch (response.code) {
      case HttpStatus.ok:
        _security = response.body;
        if (!kDebugMode) {
          developer.log("Security set: $_security", level: Level.CONFIG.value);
        }
        return _toResponse(command, _toSecurityState(), result: _security);
      case HttpStatus.unauthorized:
        return _toResponse(
          command,
          UserUnauthorized(response),
          result: false,
        );
      default:
        return _toError(command, response);
    }
  }

  Future<UserState> _load(LoadUser command) async {
    _security = (await service.getSecurity()).body;
    var response = await service.getToken();
    return _toAuthEvent(response, command);
  }

  Future<UserState> _authenticate(AuthenticateUser command) async {
    var response = await service.authorize(
      username: command.data,
      password: command.password,
    );
    return _toAuthEvent(response, command);
  }

  UserState _toAuthEvent(ServiceResponse<AuthToken> response, UserCommand command) {
    switch (response.code) {
      case HttpStatus.ok:
        _user = response.body.asUser();
        if (!kDebugMode) {
          developer.log("User parsed from token: $_user", level: Level.CONFIG.value);
        }
        return _toResponse(
          command,
          UserAuthenticated(_user),
          result: _toAuthResult(command),
        );
      case HttpStatus.noContent:
        return _toResponse(
          command,
          _toSecurityState(),
        );
      case HttpStatus.unauthorized:
        return _toResponse(
          command,
          UserUnauthorized(response),
          result: _toAuthResult(command),
        );
      case HttpStatus.forbidden:
        return _toResponse(
          command,
          UserForbidden(response),
          result: _toAuthResult(command),
        );
      default:
        return _toError(command, response);
    }
  }

  Object _toAuthResult(UserCommand command) => command is LoadUser || command is AuthenticateUser ? _user : true;

  Equatable _toSecurityState() {
    return _security == null
        ? UserUnset()
        : _security.locked
            ? UserLocked(
                _security,
              )
            : UserUnlocked(
                _security,
              );
  }

  Future<UserState> _logout(LogoutUser command) async {
    var response = await service.logout();
    if (response.is200) {
      _user = null;
      _authorized.clear();
      _security = response.body;
      return _toResponse(
        command,
        UserUnset(),
        result: true,
      );
    }
    return _toError(command, response);
  }

  UserState _authorize(AuthorizeUser command) {
    bool isCommander = user.isCommander && (command.data.passcodes.command == command.passcode);
    bool isPersonnel = user.isPersonnel && (command.data.passcodes.personnel == command.passcode);
    if (isCommander || isPersonnel) {
      var state = UserAuthorized(user, command.data, isCommander, isPersonnel);
      _authorized.putIfAbsent(command.data.id, () => state);
      return _toResponse(command, state, result: true);
    }
    return _toResponse(command, UserForbidden("Wrong passcode: ${command.passcode}"), result: false);
  }

  // Dispatch and return future
  Future<R> _dispatch<R>(UserCommand<dynamic, R> command) {
    dispatch(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  UserState _toResponse<R>(UserCommand event, UserState state, {R result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  UserState _toError(UserCommand event, Object response) {
    final error = UserError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    dispatch(RaiseUserError(UserError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UserCommand<T, R> extends Equatable {
  final T data;
  final Completer<R> callback = Completer();

  UserCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadUser extends UserCommand<void, User> {
  LoadUser() : super(null);

  @override
  String toString() => 'LoadUser';
}

class SecureUser extends UserCommand<Security, Security> {
  SecureUser(Security data) : super(data);

  @override
  String toString() => 'SecureUser {security: $data}';
}

class LockUser extends UserCommand<void, dynamic> {
  LockUser() : super(null);

  @override
  String toString() => 'LockUser';
}

class UnlockUser extends UserCommand<String, dynamic> {
  UnlockUser({String pin}) : super(pin);

  @override
  String toString() => 'UnlockUser';
}

class AuthenticateUser extends UserCommand<String, User> {
  final String password;
  AuthenticateUser(String username, this.password) : super(username, [password]);

  @override
  String toString() => 'AuthenticateUser';
}

class AuthorizeUser extends UserCommand<Incident, bool> {
  final String passcode;
  AuthorizeUser(incident, this.passcode) : super(incident, [passcode]);

  @override
  String toString() => 'AuthorizeUser';
}

class LogoutUser extends UserCommand<void, bool> {
  LogoutUser() : super(null);

  @override
  String toString() => 'LogoutUser';
}

class RaiseUserError extends UserCommand<UserError, bool> {
  RaiseUserError(data) : super(data);

  static RaiseUserError from(String error) => RaiseUserError(UserError(error));

  @override
  String toString() => 'RaiseUserError';
}

/// ---------------------
/// Normal states
/// ---------------------
abstract class UserState<T> extends Equatable {
  final T data;

  UserState(this.data, [props = const []]) : super([data, ...props]);

  isUnset() => this is UserUnset;
  isLocked() => this is UserLocked;
  isUnlocked() => this is UserUnlocked;
  isUnlocking() => this is UserUnlocking;
  isAuthenticating() => this is UserAuthenticating;
  isPending() => isUnlocking() || isAuthenticating();
  isAuthenticated() => this is UserAuthenticated;
  isAuthorized() => this is UserAuthorized;
  isException() => this is UserException;
  isUnauthorized() => this is UserUnauthorized;
  isForbidden() => this is UserForbidden;
  isError() => this is UserError;
}

class UserUnset extends UserState<void> {
  UserUnset() : super(null);
  @override
  String toString() => 'UserUnset';
}

class UserLocked extends UserState<Security> {
  UserLocked(Security data) : super(data);
  @override
  String toString() => 'UserLocked  {security: $data}';
}

class UserUnlocking extends UserState<String> {
  UserUnlocking(String pin) : super(pin);
  @override
  String toString() => 'UserUnlocking {pin: $data}';
}

class UserUnlocked extends UserState<Security> {
  UserUnlocked(Security data) : super(data);
  @override
  String toString() => 'UserUnlocked  {security: $data}';
}

class UserAuthenticating extends UserState<String> {
  UserAuthenticating(username) : super(username);
  @override
  String toString() => 'UserAuthenticating {username: $data}';
}

class UserAuthenticated extends UserState<User> {
  UserAuthenticated(user) : super(user);
  @override
  String toString() => 'UserAuthenticated {userid: ${data.userId}}';
}

class UserAuthorized extends UserState<User> {
  final Incident incident;
  final bool command;
  final bool personnel;
  UserAuthorized(
    User user,
    this.incident,
    this.command,
    this.personnel,
  ) : super(user, [incident]);
  @override
  String toString() => 'UserAuthorized';
}

/// ---------------------
/// Exceptional states
/// ---------------------
abstract class UserException extends UserState<Object> {
  final StackTrace stackTrace;
  UserException(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => 'UserError {data: $data}';
}

class UserForbidden extends UserException {
  UserForbidden(Object error, {trace}) : super(error, stackTrace: trace);

  @override
  String toString() => 'UserForbidden {data: $data}';
}

class UserUnauthorized extends UserException {
  UserUnauthorized(Object error, {trace}) : super(error, stackTrace: trace);

  @override
  String toString() => 'UserUnauthorized {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class UserError extends UserException {
  UserError(Object error, {trace}) : super(error, stackTrace: trace);

  @override
  String toString() => 'UserError {data: $data}';
}
