

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:equatable/equatable.dart';

import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:permission_handler/permission_handler.dart';

typedef void UserCallback(VoidCallback fn);

class UserBloc extends BaseBloc<UserCommand, UserState, UserBlocError>
    with LoadableBloc<User>, UnloadableBloc<List<User>?> {
  UserBloc(
    this.repo,
    this.configBloc,
    BlocEventBus bus,
  ) : super(UserUnset(), bus: bus) {
    // Notify when token changes
    registerStreamSubscription(repo.onRefresh.listen((token) {
      dispatch(_NotifyAuthTokenRefreshed(token));
    }));
  }

  final UserRepository repo;
  final AppConfigBloc? configBloc;
  final _authorized = <String?, UserAuthorized>{};

  /// [UserService] instance
  UserService? get service => repo.service;

  /// Authenticated user
  User get user => repo.user;

  /// Token for authenticated user
  AuthToken? get token => repo.token;

  /// Id of authenticated use
  String? get userId => repo.user.userId;

  /// Get [AppConfig]
  AppConfig get config => configBloc!.config;

  /// Get all user on this device
  Iterable<User>? get users => repo.values;

  /// Get current security applied to user
  Security? get security => user.security;

  /// Check if user has roles
  bool get hasRoles => user.hasRoles == true;

  /// Check if application is running on a shared device (multiple uses accounts allowed)
  bool get isShared => SecurityMode.shared == config.securityMode;

  /// Check if application is running on a private device (only one account is allowed)
  bool get isPersonal => SecurityMode.personal == config.securityMode;

  /// Get requested security mode from [AppConfig]
  SecurityMode get securityMode => config.securityMode;

  /// Get requested security type from [AppConfig]
  SecurityType get securityType => config.securityType;

  /// Get trusted domains from [AppConfig]
  List<String?> get trustedDomains => config.trustedDomains;

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

  /// User is authenticated (token can be expired)
  bool get isAuthenticated => repo.isAuthenticated;

  /// User token is valid
  bool get isTokenValid => repo.isTokenValid;

  /// User token is expired
  bool get isTokenExpired => repo.isTokenExpired;

  /// User identity is ready to be accessed (token can be expired)
  bool get isReady => isSecured && isUnlocked && isAuthenticated && !isPending;

  /// User identity is being authenticated
  bool get isAuthenticating => state.isAuthenticating();

  /// User identity is being unlocked
  bool get isUnlocking => state.isUnlocking();

  /// User identity is pending
  bool get isPending => state.isPending();

  /// Check if user has roles
  bool isAuthor(Operation data) => user.isAuthor(data) == true;

  /// Check if current [user] is authorized access to given [operation]
  bool isAuthorized(Operation? operation) {
    return isAuthenticated && (getAuthorization(operation)!.isAuthorized() || user.isAuthor(operation!));
  }

  /// Check if current [user] is authorized access to given [operation] with given [role]
  bool isAuthorizedAs(Operation? operation, UserRole role) {
    return getAuthorization(operation)?.isAuthorizedAs(role) == true;
  }

  /// Get current [user] authorization for given [operation]
  UserAuthorized? getAuthorization(Operation? operation) {
    if (isAuthenticated && operation != null) {
      // Look for passcode?
      if (!_authorized.containsKey(operation.uuid) && user.passcodes?.isNotEmpty == true) {
        final withCommanderCode = user.passcodes!.any((p) => operation.passcodes!.commander == p.commander);
        final withPersonnelCode = user.passcodes!.any((p) => operation.passcodes!.personnel == p.personnel);
        if (withPersonnelCode || withCommanderCode) {
          _authorized[operation.uuid] = UserAuthorized(
            user,
            withPersonnelCode: withPersonnelCode,
            withCommanderCode: withCommanderCode,
          );
        }
      }
      if (_authorized.containsKey(operation.uuid)) {
        return _authorized[operation.uuid];
      }
      if (user.userId == operation.author!.userId) {
        return UserAuthorized(
          user,
          operation: operation,
          withCommanderCode: true,
          withPersonnelCode: true,
        );
      }
    }
    return UserAuthorized(
      user,
      operation: operation,
      withCommanderCode: false,
      withPersonnelCode: false,
    );
  }

  /// Secure user access with given settings
  Future<Security?> secure(String? pin, {bool? locked}) async {
    return dispatch<Security>(SecureUser(pin, locked: locked));
  }

  /// Lock user access using current security settings
  Future<dynamic> lock() async {
    return dispatch<dynamic>(LockUser());
  }

  /// Unlock user access
  Future<dynamic> unlock(String? pin) async {
    return dispatch<dynamic>(UnlockUser(pin));
  }

  /// Load current user from secure storage
  Future<User> load() async {
    return dispatch<User>(
      LoadUser(userId: userId ?? repo.userId),
    );
  }

  /// Authenticate user
  Future<User> login({String? userId, String? username, String? password, String? idpHint}) {
    return dispatch<User>(LoginUser(
      userId: userId,
      username: username,
      password: password,
      idpHint: idpHint,
    ));
  }

  Future<User> logout({bool delete = false}) {
    return dispatch<User>(LogoutUser(delete: delete));
  }

  Future<List<User>?> unload() {
    return dispatch<List<User>>(UnloadUsers());
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

  Future<bool?> authorize(Operation data, String passcode) {
    return dispatch<bool>(_assertAuthenticated<User>(
      AuthorizeUser(data, passcode),
    ));
  }

  @override
  Stream<UserState> execute(UserCommand command) async* {
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
      yield await _authorize(command);
    } else if (command is _NotifyAuthTokenRefreshed) {
      yield _notify(command);
    } else {
      yield toUnsupported(command);
    }
  }

  Future<UserState> _secure(SecureUser command) async {
    try {
      final response = await repo.secure(
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
      final domain =UserService.toDomain(email);
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
      final user = await repo.load(
        userId: command.data,
      );
      return _toEvent(
        command,
        user,
      );
    } on Exception catch (e) {
      return _toEvent(command, e);
    }
  }

  Future<UserState> _authenticate(LoginUser command) async {
    try {
      final response = await repo.login(
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
    final user = await repo.logout(
      delete: command.data,
    );
    _authorized.clear();
    return toOK(
      command,
      UserUnset(),
      result: user,
    );
  }

  Future<UserState> _unload(UnloadUsers command) async {
    await repo.logout();
    final users = await repo.clear();
    _authorized.clear();
    return toOK(
      command,
      UserUnset(),
      result: users,
    );
  }

  UserState _notify(_NotifyAuthTokenRefreshed command) {
    return toOK(
      command,
      AuthTokenRefreshed(command.data),
      result: command.data,
    );
  }

  Future<UserState> _authorize(AuthorizeUser command) async {
    bool withCommanderCode = command.data.passcodes!.commander == command.passcode;
    bool withPersonnelCode = command.data.passcodes!.personnel == command.passcode;
    if (withCommanderCode || withPersonnelCode) {
      await repo.authorize(
        command.data.passcodes,
      );
      final state = UserAuthorized(
        user,
        operation: command.data,
        withCommanderCode: withCommanderCode,
        withPersonnelCode: withPersonnelCode,
      );
      _authorized[command.data.uuid] = state;

      return toOK(
        command,
        state,
        result: true,
      );
    }
    return toOK(
      command,
      UserForbidden("Wrong passcode: ${command.passcode}"),
      result: false,
    );
  }

  UserState _toEvent(UserCommand command, Object? result) {
    if (result == null) {
      if (kDebugMode) {
        developer.log("No user found", level: Level.CONFIG.value);
      }

      _configure();

      return toOK(
        command,
        UserUnset(),
        result: _toAuthResult(command),
      );
    } else if (result is User) {
      if (kDebugMode) {
        developer.log("User parsed from token: $user", level: Level.CONFIG.value);
      }

      _configure();

      return toOK(
        command,
        (isTokenExpired ? AuthTokenExpired(token) : UserAuthenticated(user)) as UserState<dynamic>,
        result: _toAuthResult(command),
      );
    } else if (result is Security) {
      if (kDebugMode) {
        developer.log("Security set: $security", level: Level.CONFIG.value);
      }
      return toOK(
        command,
        _toSecurityState() as UserState<dynamic>,
        result: security,
      );
    } else if (result is UserNotFoundException ||
        result is UserNotSecuredException ||
        result is UserUnauthorizedException) {
      return toError(
        command,
        UserUnauthorized(result),
      );
    } else if (result is UserForbiddenException) {
      return toError(
        command,
        UserForbidden(result),
      );
    } else if (result is UserRepositoryOfflineException) {
      return toError(
        command,
        UserBlocIsOffline(result),
      );
    }
    return toError(
      command,
      UserBlocError(
        'Unknown result: $result',
        stackTrace: StackTrace.current,
      ),
    );
  }

  /// Configure app config
  ///
  /// 1) A new app-config will be created after first install.
  /// 2) If user is not authorized local AppConfig instance is created
  /// 3) If user authorized local changes is pushed to server
  Future _configure() async {
    if (configBloc!.repo.isEmpty) {
      if (isAuthenticated) {
        await configBloc!.load();
        await _updatePermissions();
      } else {
        await configBloc!.init(local: true);
      }
    } else if (isAuthenticated) {
      await configBloc!.repo.commit();
    }
  }

  Future _updatePermissions() async {
    var isStorageGranted = Platform.isAndroid ? await Permission.storage.isGranted : false;
    var isLocationAlwaysGranted = await Permission.locationAlways.isGranted;
    var isLocationWhenInUseGranted = await Permission.locationWhenInUse.isGranted;
    var isActivityRecognitionGranted = await Permission.activityRecognition.isGranted;
    final config = configBloc!.config;
    if (config.storage != isStorageGranted ||
        config.locationAlways != isLocationAlwaysGranted ||
        config.locationWhenInUse != isLocationWhenInUseGranted ||
        config.activityRecognition != isActivityRecognitionGranted) {
      await configBloc!.updateWith(
        storage: isStorageGranted,
        locationAlways: isLocationAlwaysGranted,
        locationWhenInUse: isLocationWhenInUseGranted,
        activityRecognition: isActivityRecognitionGranted,
      );
    }
  }

  Object? _toAuthResult(UserCommand command) {
    return command is LoadUser || command is LoginUser ? user : true;
  }

  Equatable _toSecurityState() {
    return security == null
        ? UserUnset()
        : security!.locked!
            ? UserLocked(
                security,
              )
            : UserUnlocked(
                security,
              );
  }

  @override
  UserBlocError createError(Object error, {StackTrace? stackTrace}) => UserBlocError(
        error,
        stackTrace: stackTrace ?? StackTrace.current,
      );

  @override
  Future<void> close() {
    repo.dispose();
    return super.close();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class UserCommand<S, T> extends BlocCommand<S, T> {
  UserCommand(S data, [props = const []]) : super(data, props);
}

class LoadUser extends UserCommand<String?, User> {
  LoadUser({String? userId}) : super(null);

  @override
  String toString() => '$runtimeType {userId: $data}';
}

class SecureUser extends UserCommand<String?, Security> {
  final bool? locked;
  SecureUser(String? pin, {this.locked}) : super(pin);

  @override
  String toString() => '$runtimeType {pin: $data, locked: $locked}';
}

class LockUser extends UserCommand<void, Security> {
  LockUser() : super(null);

  @override
  String toString() => '$runtimeType';
}

class UnlockUser extends UserCommand<String?, Security> {
  UnlockUser(String? pin) : super(pin);

  @override
  String toString() => '$runtimeType {pin: $data}';
}

class LoginUser extends UserCommand<String?, User> {
  final String? userId;
  final String? password;
  final String? idpHint;
  LoginUser({
    String? username,
    this.password,
    this.userId,
    this.idpHint,
  }) : super(username, [
          userId,
          password,
          idpHint,
        ]);

  @override
  String toString() => '$runtimeType {username: $data, password: $data, idpHint: $idpHint}';
}

class AuthorizeUser extends UserCommand<Operation, bool> {
  final String passcode;
  AuthorizeUser(Operation data, this.passcode) : super(data, [passcode]);

  @override
  String toString() => '$runtimeType';
}

class LogoutUser extends UserCommand<bool, User> {
  LogoutUser({bool delete = false}) : super(delete);

  @override
  String toString() => 'runtimeType {data: $data}';
}

class UnloadUsers extends UserCommand<void, List<User>> {
  UnloadUsers() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class _NotifyAuthTokenRefreshed extends UserCommand<AuthToken, AuthToken> {
  _NotifyAuthTokenRefreshed(AuthToken token) : super(token);

  @override
  String toString() => '$runtimeType {}';
}

/// ---------------------
/// Normal states
/// ---------------------
abstract class UserState<T> extends BlocState<T> {
  UserState(
    T data, {
    StackTrace? stackTrace,
    props = const [],
  }) : super(data, props: props, stackTrace: stackTrace);

  bool isUnset() => this is UserUnset;
  bool isLocked() => this is UserLocked;
  bool isUnlocked() => this is UserUnlocked;
  bool isUnlocking() => this is UserUnlocking;
  bool isAuthenticating() => this is UserAuthenticating;
  bool isPending() => isUnlocking() || isAuthenticating();
  bool isAuthenticated() => this is UserAuthenticated;
  bool isTokenExpired() => this is AuthTokenRefreshed;
  bool isTokenRefreshed() => this is AuthTokenRefreshed;
  bool isAuthorized() => this is UserAuthorized;
  bool isUnauthorized() => this is UserUnauthorized;
  bool isForbidden() => this is UserForbidden;
  bool isOffline() => this is UserBlocIsOffline;
  bool isError() => this is UserBlocError;

  bool shouldLoad() => isAuthenticated() || isAuthorized() || isUnlocked() || isTokenRefreshed();
  bool shouldUnload({
    bool isOnline = true,
  }) =>
      !(shouldLoad() || isPending() || isForbidden()) || isUnset() || isOnline && isUnauthorized();
}

class UserUnset extends UserState<void> {
  UserUnset() : super(null);
  @override
  String toString() => '$runtimeType';
}

class UserLocked extends UserState<Security?> {
  UserLocked(Security? data) : super(data);
  @override
  String toString() => '$runtimeType {security: $data}';
}

class UserUnlocking extends UserState<String?> {
  UserUnlocking(String? pin) : super(pin);
  @override
  String toString() => '$runtimeType {pin: $data}';
}

class UserUnlocked extends UserState<Security?> {
  UserUnlocked(Security? data) : super(data);
  @override
  String toString() => '$runtimeType  {security: $data}';
}

class UserAuthenticating extends UserState<String?> {
  UserAuthenticating(String? username) : super(username);
  @override
  String toString() => '$runtimeType {username: $data}';
}

class UserAuthenticated extends UserState<User> {
  UserAuthenticated(User user) : super(user);
  @override
  String toString() => '$runtimeType {userid: ${data.userId}}';
}

class UserAuthorized extends UserState<User> {
  UserAuthorized(
    User user, {
    this.operation,
    this.withCommanderCode,
    this.withPersonnelCode,
  }) : super(user, props: [
          operation,
          withCommanderCode,
          withPersonnelCode,
        ]);

  final Operation? operation;
  final bool? withCommanderCode;
  final bool? withPersonnelCode;

  @override
  bool isAuthorized() => withPersonnelCode == true || withCommanderCode == true;

  bool get isMobilized => operation != null;
  bool get isCommander => data.isCommander == true;
  bool get isPersonnel => data.isPersonnel == true;
  bool get isUnitLeader => data.isUnitLeader == true;
  bool get isPlanningChief => data.isPlanningChief == true;
  bool get isOperationsChief => data.isOperationsChief == true;
  bool get isAuthor => data != null && operation?.author?.userId == data.userId;
  bool get isLeader => isCommander || isUnitLeader || isPlanningChief || isOperationsChief;

  /// Check [User] [data] is authorized access to given [operation] with given [role]
  ///
  /// If [isAuthor] user is authorized for all roles.
  ///
  bool isAuthorizedAs(UserRole role) {
    if (isAuthor) {
      return true;
    }
    final available = !isMobilized;

    switch (role) {
      case UserRole.commander:
        return isCommander && (available || withCommanderCode!);
      case UserRole.planning_chief:
        return isPlanningChief && (available || withCommanderCode!);
      case UserRole.operations_chief:
        return isOperationsChief && (available || withCommanderCode!);
      case UserRole.unit_leader:
        return isUnitLeader && (available || withCommanderCode!);
      case UserRole.personnel:
        return available || withCommanderCode! || withPersonnelCode!;
      default:
        return false;
    }
  }

  String toString() => '$runtimeType {user: $data, command: $withCommanderCode, personnel: $withPersonnelCode}';
}

class AuthTokenExpired extends UserState<AuthToken?> {
  AuthTokenExpired(AuthToken? token) : super(token);
  @override
  String toString() => '$runtimeType {userId: ${data!.userId}}';
}

class AuthTokenRefreshed extends UserState<AuthToken> {
  AuthTokenRefreshed(AuthToken token) : super(token);
  @override
  String toString() => '$runtimeType {userId: ${data.userId}}';
}

/// ---------------------
/// Error states
/// ---------------------

class UserBlocError extends UserState<Object?> {
  UserBlocError(
    Object error, {
    StackTrace? stackTrace,
  }) : super(error, stackTrace: stackTrace);

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
  final UserCommand? command;
  final UserState state;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType {state: $state, command: $command, stackTrace: $stackTrace}';
}
