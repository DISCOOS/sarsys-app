import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:equatable/equatable.dart';

import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/user_service.dart';

import 'app_config_bloc.dart';
import 'mixins.dart';

typedef void UserCallback(VoidCallback fn);

class UserBloc extends Bloc<UserCommand, UserState> with LoadableBloc<User>, UnloadableBloc<List<User>> {
  UserBloc(this.repo, this.configBloc);

  final UserRepository repo;
  final AppConfigBloc configBloc;
  final LinkedHashMap<String, UserAuthorized> _authorized = LinkedHashMap();

  UserService get service1 => repo.service;

  @override
  UserUnset get initialState => UserUnset();

  /// Authenticated use
  User get user => repo.user;

  /// Id of authenticated use
  String get userId => repo.user?.userId;

  /// Get [AppConfig]
  AppConfig get config => configBloc.config;

  /// Get all user on this device
  Iterable<User> get users => repo.values;

  /// Get current security applied to user
  Security get security => user?.security;

  /// Check if user has roles
  bool get hasRoles => user?.hasRoles == true;

  /// Check if application is running on a shared device (multiple uses accounts allowed)
  bool get isShared => SecurityMode.shared == config.securityMode;

  /// Check if application is running on a private device (only one account is allowed)
  bool get isPersonal => SecurityMode.personal == config.securityMode;

  /// Get requested security mode from [AppConfig]
  SecurityMode get securityMode => config.securityMode;

  /// Get requested security type from [AppConfig]
  SecurityType get securityType => config.securityType;

  /// Get trusted domains from [AppConfig]
  List<String> get trustedDomains => config.trustedDomains;

  /// User identity is secured
  bool get isSecured => security != null;

  /// User access is locked. This should enforce login
  bool get isLocked => !isSecured || security?.locked == true;

  /// User access is unlocked
  bool get isUnlocked => security?.locked == false;

  /// User is in a trusted domain
  bool get isTrusted => security?.trusted == true;

  /// User is in a untrusted domain
  bool get isUntrusted => security?.trusted == false;

  /// User is authenticated
  bool get isAuthenticated => repo.isAuthenticated;

  /// User identity is ready to be accessed. If false, login should be enforced
  bool get isReady => isSecured && isUnlocked && isAuthenticated && !isPending;

  /// User identity is being authenticated
  bool get isAuthenticating => state.isAuthenticating();

  /// User identity is being unlocked
  bool get isUnlocking => state.isUnlocking();

  /// User identity is pending
  bool get isPending => state.isPending();

  /// Check if user has roles
  bool isAuthor(Incident incident) => user?.isAuthor(incident) == true;

  /// Check if current user is authorized to access given [Incident]
  bool isAuthorized(Incident data) {
    return isAuthenticated && (_authorized.containsKey(data.uuid) || user.isAuthor(data));
  }

  /// Check if current user is authorized to access given [Incident]
  UserAuthorized getAuthorization(Incident data) {
    if (isAuthenticated) {
      if (_authorized.containsKey(data.uuid)) return _authorized[data.uuid];
      if (user?.userId == data.created.userId) return UserAuthorized(user, data, true, true);
    }
    return null;
  }

  /// Get trusted organization given in [AppConfig]
  Future<Organization> getTrustedOrg() async => FleetMapService().fetchOrganization(
        config.orgId,
      );

  /// Stream of authorization state changes
  Stream<bool> authorized(Incident incident) => map(
        (state) => state is UserAuthorized && state.incident == incident,
      );

  /// Secure user access with given settings
  Future<Security> secure(String pin, {bool locked}) async {
    return _dispatch<Security>(SecureUser(pin, locked: locked));
  }

  /// Lock user access using current security settings
  Future<dynamic> lock() async {
    return _dispatch<dynamic>(LockUser());
  }

  /// Unlock user access
  Future<dynamic> unlock(String pin) async {
    return _dispatch<dynamic>(UnlockUser(pin));
  }

  /// Load current user from secure storage
  Future<User> load() async {
    return _dispatch<User>(LoadUser(userId: userId ?? repo.userId));
  }

  /// Authenticate user
  Future<User> login({String userId, String username, String password, String idpHint}) {
    return _dispatch<User>(LoginUser(
      userId: userId,
      username: username,
      password: password,
      idpHint: idpHint,
    ));
  }

  Future<User> logout({bool delete = false}) {
    return _dispatch<User>(LogoutUser(delete: delete));
  }

  Future<List<User>> unload() {
    return _dispatch<List<User>>(UnloadUsers());
  }

  UserCommand _assertAuthenticated<T>(UserCommand command) {
    if (isAuthenticated) {
      return command;
    }
    throw UserBlocError(
      "User is not logged",
      stackTrace: StackTrace.current,
    );
  }

  Future<bool> authorize(Incident data, String passcode) {
    return _dispatch<bool>(_assertAuthenticated<User>(AuthorizeUser(data, passcode)));
  }

  @override
  Stream<UserState> mapEventToState(UserCommand command) async* {
    try {
      if (command is LoadUser) {
        yield await _load(command);
      } else if (command is LoginUser) {
        yield UserAuthenticating(command.data);
        yield await _authenticate(command);
      } else if (command is SecureUser) {
        yield await _secure(command);
      } else if (command is LockUser) {
        yield await _lock(command);
      } else if (command is UnlockUser) {
        yield UserUnlocking(command.data);
        yield await _unlock(command);
      } else if (command is LogoutUser) {
        yield await _logout(command);
      } else if (command is UnloadUsers) {
        yield await _unload(command);
      } else if (command is AuthorizeUser) {
        yield _authorize(command);
      } else {
        yield _toError(
          command,
          UserBlocError(
            "Unsupported $command",
            stackTrace: StackTrace.current,
          ),
        );
      }
    } on Exception catch (error, stackTrace) {
      yield _toError(
        command,
        UserBlocError(
          error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<UserState> _secure(SecureUser command) async {
    try {
      var response = await repo.secure(
        command.data,
        trusted: trustUser(),
        locked: command.locked,
        type: config.securityType,
        mode: config.securityMode,
      );
      return _toEvent(command, response);
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  bool trustUser() {
    final email = user.email;
    if (email != null) {
      final domain = UserService.toDomain(email);
      return config.trustedDomains.contains(domain);
    }
    return false;
  }

  Future<UserState> _lock(LockUser command) async {
    try {
      return _toEvent(
        command,
        await repo.lock(),
      );
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  Future<UserState> _unlock(UnlockUser command) async {
    try {
      return _toEvent(
        command,
        await repo.unlock(command.data),
      );
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  Future<UserState> _load(LoadUser command) async {
    try {
      return _toEvent(
        command,
        await repo.load(userId: command.data),
      );
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  Future<UserState> _authenticate(LoginUser command) async {
    try {
      var response = await repo.login(
        username: command.data,
        password: command.password,
        userId: command.userId,
        idpHint: command.idpHint,
      );
      return _toEvent(command, response);
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  Future<UserState> _logout(LogoutUser command) async {
    var user = await repo.logout(
      delete: command.data,
    );
    _authorized.clear();
    return _toOK(
      command,
      UserUnset(),
      result: user,
    );
  }

  Future<UserState> _unload(UnloadUsers command) async {
    await repo.logout();
    var users = await repo.clear();
    _authorized.clear();
    return _toOK(
      command,
      UserUnset(),
      result: users,
    );
  }

  UserState _authorize(AuthorizeUser command) {
    bool isCommander = user.isCommander && (command.data.passcodes.command == command.passcode);
    bool isPersonnel = user.isPersonnel && (command.data.passcodes.personnel == command.passcode);
    if (isCommander || isPersonnel) {
      var state = UserAuthorized(user, command.data, isCommander, isPersonnel);
      _authorized.putIfAbsent(command.data.uuid, () => state);
      return _toOK(command, state, result: true);
    }
    return _toOK(command, UserForbidden("Wrong passcode: ${command.passcode}"), result: false);
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(UserCommand<dynamic, T> command) {
    add(command);
    return command.callback.future;
  }

  UserState _toEvent(UserCommand command, Object result) {
    if (result == null) {
      return _toOK(
        command,
        UserUnset(),
        result: _toAuthResult(command),
      );
    } else if (result is User) {
      if (kDebugMode) {
        developer.log("User parsed from token: $user", level: Level.CONFIG.value);
      }
      return _toOK(
        command,
        UserAuthenticated(user),
        result: _toAuthResult(command),
      );
    } else if (result is Security) {
      if (kDebugMode) {
        developer.log("Security set: $security", level: Level.CONFIG.value);
      }
      return _toOK(
        command,
        _toSecurityState(),
        result: security,
      );
    } else if (result is UserNotFoundException ||
        result is UserNotSecuredException ||
        result is UserUnauthorizedException) {
      return _toError(
        command,
        UserUnauthorized(result),
      );
    } else if (result is UserForbiddenException) {
      return _toError(
        command,
        UserForbidden(result),
      );
    } else if (result is UserRepositoryOfflineException) {
      return _toError(
        command,
        UserBlocIsOffline(result),
      );
    }
    return _toError(
      command,
      UserBlocError(
        'Unknown result: $result',
        stackTrace: StackTrace.current,
      ),
    );
  }

  Object _toAuthResult(UserCommand command) {
    return command is LoadUser || command is LoginUser ? user : true;
  }

  Equatable _toSecurityState() {
    return security == null
        ? UserUnset()
        : security.locked
            ? UserLocked(
                security,
              )
            : UserUnlocked(
                security,
              );
  }

  // Complete request and return given state to bloc
  UserState _toOK<T>(UserCommand event, UserState state, {T result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  UserState _toError(UserCommand command, Object error) {
    final object = error is UserBlocError
        ? error
        : UserBlocError(
            error,
            stackTrace: StackTrace.current,
          );
    command.callback.completeError(
      object.data,
      object.stackTrace ?? StackTrace.current,
    );
    return object;
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UserCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();

  UserCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadUser extends UserCommand<String, User> {
  LoadUser({String userId}) : super(null);

  @override
  String toString() => 'LoadUser {userId: $data}';
}

class SecureUser extends UserCommand<String, Security> {
  final bool locked;
  SecureUser(String pin, {this.locked}) : super(pin);

  @override
  String toString() => 'SecureUser {pin: $data, locked: $locked}';
}

class LockUser extends UserCommand<void, Security> {
  LockUser() : super(null);

  @override
  String toString() => 'LockUser';
}

class UnlockUser extends UserCommand<String, Security> {
  UnlockUser(String pin) : super(pin);

  @override
  String toString() => 'UnlockUser {pin: $data}';
}

class LoginUser extends UserCommand<String, User> {
  final String userId;
  final String password;
  final String idpHint;
  LoginUser({
    String username,
    this.password,
    this.userId,
    this.idpHint,
  }) : super(username, [
          userId,
          password,
          idpHint,
        ]);

  @override
  String toString() => 'AuthenticateUser  {username: $data, password: $data}';
}

class AuthorizeUser extends UserCommand<Incident, bool> {
  final String passcode;
  AuthorizeUser(incident, this.passcode) : super(incident, [passcode]);

  @override
  String toString() => 'AuthorizeUser';
}

class LogoutUser extends UserCommand<bool, User> {
  LogoutUser({bool delete = false}) : super(delete);

  @override
  String toString() => 'LogoutUser {data: $data}';
}

class UnloadUsers extends UserCommand<void, List<User>> {
  UnloadUsers() : super(null);

  @override
  String toString() => 'UnloadUsers {}';
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
  isUnauthorized() => this is UserUnauthorized;
  isForbidden() => this is UserForbidden;
  isOffline() => this is UserBlocIsOffline;
  isError() => this is UserBlocError;
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
  UserAuthenticating(String username) : super(username);
  @override
  String toString() => 'UserAuthenticating {username: $data}';
}

class UserAuthenticated extends UserState<User> {
  UserAuthenticated(User user) : super(user);
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
/// Error states
/// ---------------------

class UserBlocError extends UserState<Object> {
  final StackTrace stackTrace;
  UserBlocError(Object error, {this.stackTrace}) : super(error);

  @override
  String toString() => '$runtimeType {error: $data, stackTrace: $stackTrace}';
}

class UserForbidden extends UserBlocError {
  UserForbidden(Object error) : super(error);

  @override
  String toString() => 'UserForbidden {error: $data}';
}

class UserUnauthorized extends UserBlocError {
  UserUnauthorized(Object error) : super(error);

  @override
  String toString() => 'UserUnauthorized {error: $data}';
}

class UserBlocIsOffline extends UserBlocError {
  UserBlocIsOffline(Object error) : super(error);

  @override
  String toString() => 'UserIsOffline {error: $data}';
}

/// ---------------------
/// Exceptions
/// ---------------------

class UserBlocException implements Exception {
  UserBlocException(this.state, {this.command, this.stackTrace});
  final UserCommand command;
  final UserState state;
  final StackTrace stackTrace;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
