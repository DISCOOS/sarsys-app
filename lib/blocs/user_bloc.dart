import 'dart:collection';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter/foundation.dart' show VoidCallback, kReleaseMode;

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

  /// Initialize from service
  Future<bool> init() async {
    var token = await service.getToken();
    if (token != null) {
      print("Init from token f$token");
      dispatch(InitUser(User.fromToken(token)));
    }
    return Future.value(isAuthenticated);
  }

  UserBloc login(String username, String password) {
    dispatch(_assertUnset(AuthenticateUser(username, password)));
    return this;
  }

  UserCommand _assertUnset(UserCommand command) {
    return isAuthenticated ? RaiseUserError.from("Ikke logget inn") : command;
  }

  UserBloc logout() {
    dispatch(_assertAuthenticated(UnsetUser()));
    return this;
  }

  UserBloc authorize(Incident data, String passcode) {
    dispatch(_assertAuthenticated(AuthorizeUser(data, passcode)));
    return this;
  }

  UserCommand _assertAuthenticated(UserCommand command) {
    return isAuthenticated ? command : RaiseUserError.from("Ikke logget inn");
  }

  @override
  Stream<UserState> mapEventToState(UserCommand command) async* {
    if (command is InitUser) {
      yield _init(command);
    } else if (command is AuthenticateUser) {
      yield UserAuthenticating(command.data);
      yield await _authenticate(command);
    } else if (command is UnsetUser) {
      if (_user != null) {
        yield await _unset();
      }
    } else if (command is AuthorizeUser) {
      if (_user != null) {
        yield _authorize(command.data, command.passcode);
      }
    } else if (command is RaiseUserError) {
      yield command.data;
    } else {
      yield UserError("Unsupported $command");
    }
  }

  UserState _init(InitUser command) {
    _user = command.data;
    return UserAuthenticated(_user);
  }

  Future<UserState> _authenticate(AuthenticateUser command) async {
    if (await service.login(command.data, command.password)) {
      _user = User.fromToken(await service.getToken());
      return UserAuthenticated(_user);
    }
    return UserError("Feil ved innlogging - tjeneste ikke tilgjengelig");
  }

  Future<UserUnset> _unset() async {
    await service.logout();
    _user = null;
    _authorized.clear();
    return UserUnset();
  }

  _authorize(Incident data, String passcode) {
    bool command = data.passcodes.personnel == passcode;
    bool personnel = command || data.passcodes.personnel == passcode;
    if (command || personnel) {
      var state = UserAuthorized(user, data, command, personnel);
      _authorized.putIfAbsent(data.id, () => state);
      return state;
    }
    return UserForbidden("Feil kode: $passcode");
  }

  @override
  void onEvent(UserCommand event) {
    if (!kReleaseMode) print("Command $event");
  }

  @override
  void onTransition(Transition<UserCommand, UserState> transition) {
    if (!kReleaseMode) print("$transition");
  }

  /// Throw error to stream
  @override
  void onError(Object error, StackTrace stacktrace) {
    if (!kReleaseMode) print("Error $error, stacktrace: $stacktrace");
    dispatch(RaiseUserError(UserError(error, trace: stacktrace)));
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UserCommand<T> extends Equatable {
  final T data;

  UserCommand(this.data, [props = const []]) : super([data, ...props]);
}

class UnsetUser extends UserCommand<Null> {
  UnsetUser() : super(null);

  @override
  String toString() => 'UnsetUser';
}

class InitUser extends UserCommand<User> {
  InitUser(User user) : super(user);

  @override
  String toString() => 'InitUser';
}

class AuthenticateUser extends UserCommand<String> {
  final String password;
  AuthenticateUser(String username, this.password) : super(username, [password]);

  @override
  String toString() => 'AuthenticateUser';
}

class AuthorizeUser extends UserCommand<Incident> {
  final String passcode;
  AuthorizeUser(incident, this.passcode) : super(incident, [passcode]);

  @override
  String toString() => 'AuthorizeUser';
}

class RaiseUserError extends UserCommand<UserError> {
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
