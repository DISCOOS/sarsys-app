import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
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

  User _user;
  User get user => _user;
  bool get isAuthenticated => _user != null;

  /// Stream of authentication state changes
  Stream<bool> get authenticated => state.map((state) => state is UserAuthenticated);

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

  /// Load user from secure storage
  Future<bool> load() async {
    return _dispatch<bool>(_assertUnset(LoadUser()));
  }

  Future<bool> login(String username, String password) {
    return _dispatch<bool>(_assertUnset(AuthenticateUser(username, password)));
  }

  UserCommand _assertUnset(UserCommand command) {
    return isAuthenticated ? RaiseUserError.from("Allerede logget inn") : command;
  }

  Future<bool> logout() {
    return _dispatch<bool>(_assertAuthenticated(UnsetUser()));
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
      if (command is LoadUser) {
        yield await _load(command);
      } else if (command is AuthenticateUser) {
        yield UserAuthenticating(command.data);
        yield await _authenticate(command);
      } else if (command is UnsetUser) {
        if (_user != null) {
          yield await _logout(command);
        }
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

  Future<UserState> _load(LoadUser command) async {
    var response = await service.getToken();
    if (response.is200) {
      _user = User.fromToken(response.body);
      if (!kDebugMode) developer.log("Init from token ${response.body}", level: Level.CONFIG.value);
      return _toResponse(command, UserAuthenticated(_user), result: true);
    } else if (response.is401) {
      return _toResponse(command, UserUnauthorized(_user), result: false);
    }
    return _toError(command, response);
  }

  Future<UserState> _authenticate(AuthenticateUser command) async {
    var response = await service.login(command.data, command.password);
    if (response.is200) {
      _user = User.fromToken(response.body);
      return _toResponse(command, UserAuthenticated(_user), result: true);
    } else if (response.is401) {
      return _toResponse(command, UserUnauthorized(response), result: false);
    } else if (response.is403) {
      return _toResponse(command, UserForbidden(response), result: false);
    }
    return _toError(command, response);
  }

  Future<UserUnset> _logout(UnsetUser command) async {
    var response = await service.logout();
    if (response.is204) {
      _user = null;
      _authorized.clear();
      return _toResponse(command, UserUnset(), result: true);
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

class UnsetUser extends UserCommand<void, bool> {
  UnsetUser() : super(null);

  @override
  String toString() => 'UnsetUser';
}

class LoadUser extends UserCommand<void, bool> {
  LoadUser() : super(null);

  @override
  String toString() => 'LoadUser';
}

class AuthenticateUser extends UserCommand<String, bool> {
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
  isAuthenticating() => this is UserAuthenticating;
  isAuthenticated() => this is UserAuthenticated;
  isAuthorized() => this is UserAuthorized;
  isException() => this is UserException;
  isUnauthorized() => this is UserUnauthorized;
  isForbidden() => this is UserForbidden;
  isError() => this is UserError;
}

class UserUnset extends UserState<Null> {
  UserUnset() : super(null);
  @override
  String toString() => 'UserUnset';
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
    user,
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
