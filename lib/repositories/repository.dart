import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Base class for implementing a stateful
/// repository that is aware of connection status.
///
/// Use this class to implement a repository that
/// should cache all changes locally before
/// attempting to push them to a backend API.
///
abstract class ConnectionAwareRepository<S, T extends Aggregate> {
  ConnectionAwareRepository({
    @required this.connectivity,
    this.compactWhen = 10,
  });
  final int compactWhen;
  final ConnectivityService connectivity;
  final StreamController<StorageState<T>> _controller = StreamController.broadcast();

  /// Get stream of state changes
  Stream<StorageState<T>> get changes => _controller.stream;

  /// Check if repository is empty
  ///
  /// If [isReady] is [true], then [isNotEmpty] is always [false]
  bool get isNotEmpty => !isEmpty;

  /// Check if repository is empty.
  ///
  /// If [isReady] is [true], then [isEmpty] is always [true]
  bool get isEmpty => !isReady || _states.isEmpty;

  /// Check if repository is online
  get isOnline => connectivity.isOnline;

  /// Check if repository is offline
  get isOffline => connectivity.isOffline;

  /// Get value from [key]
  T operator [](S key) => get(key);

  /// Get number of states
  int get length => _isReady ? _states.length : 0;

  /// Get value from [key]
  T get(S key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(S key) => containsKey(key) ? _states?.get(key) : null;

  /// Get backlog of states pending push to a backend API
  Iterable<S> get backlog => List.unmodifiable(_backlog);
  final _backlog = LinkedHashSet();

  /// Get all states as unmodifiable map
  Map<S, StorageState<T>> get states => Map.unmodifiable(_isReady ? _states?.toMap() : {});
  Box<StorageState<T>> _states;

  /// Get all (key,value)-pairs as unmodifiable map
  Map<S, T> get map => Map.unmodifiable(_isReady
      ? Map.fromIterables(
          _states?.keys,
          _states?.values?.map(
            (s) => s.value,
          ))
      : {});

  /// Get all keys as unmodifiable list
  Iterable<S> get keys => List.unmodifiable(_isReady ? _states?.keys : []);

  /// Get all values as unmodifiable list
  Iterable<T> get values => List.unmodifiable(_isReady ? _states?.values?.map((state) => state.value) : []);

  /// Check if key exists
  bool containsKey(S key) => _isReady ? _states.keys.contains(key) : false;

  /// Check if value exists
  bool containsValue(T value) => _isReady ? _states.values.any((state) => state.value == value) : false;

  /// Check if repository is operational
  @mustCallSuper
  bool get isReady => _isReady;
  bool get _isReady => _states?.isOpen == true;

  /// Asserts that repository is operational.
  /// Should be called before methods is called.
  /// If not ready an [RepositoryNotReadyException] is thrown
  @protected
  void checkState() {
    if (_states?.isOpen != true) {
      throw RepositoryNotReadyException();
    } else if (_closed) {
      throw RepositoryIsClosedException();
    }
  }

  /// Get key [S] from state [T]
  S toKey(StorageState<T> state);

  /// Should create state in backend
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onCreate(StorageState<T> state);

  /// Should update state in backend
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onUpdate(StorageState<T> state);

  /// Should delete state in backend
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onDelete(StorageState<T> state);

  /// Should handle errors
  @visibleForOverriding
  void onError(Object error, StackTrace stackTrace) {
    RepositorySupervisor.delegate.onError(this, error, stackTrace);
  }

  /// Reads [states] from storage
  @visibleForOverriding
  Future<Iterable<StorageState<T>>> prepare({
    String postfix,
    bool force = false,
    bool compact = false,
  }) async {
    if (force || _states == null) {
      if (compact) {
        await _states?.compact();
      }
      await _states?.close();
      _states = await Hive.openBox(
        ['$runtimeType', postfix].where((part) => !isEmptyOrNull(part)).join('_'),
        encryptionKey: await Storage.hiveKey<T>(),
        compactionStrategy: (_, deleted) => compactWhen < deleted,
      );
      // Add local states to backlog
      _backlog
        ..clear()
        ..addAll(
          _states.values.where((state) => state.isCreated).map((state) => toKey(state)),
        );
    }
    return states.values;
  }

  /// Apply [next] and push to remote
  @visibleForOverriding
  FutureOr<T> apply(
    StorageState<T> state,
  ) async {
    checkState();
    final next = validate(state);
    final exists = await commit(next);
    if (exists && next.isLocal) {
      if (connectivity.isOnline) {
        try {
          final value = await _push(
            next,
          );
          await commit(
            next.remote(value),
          );
          return value;
        } on SocketException {
          // Timeout - try again later
        } on Exception catch (error, stackTrace) {
          onError(error, stackTrace);
        }
      } // if offline or a SocketException was thrown
      return _offline(next);
    } // if state is remote
    return next.value;
  }

  /// Subscription for handling  offline -> online
  StreamSubscription<ConnectivityStatus> _pending;

  T _offline(StorageState<T> state) {
    final key = toKey(state);
    _backlog.add(key);
    if (_pending == null) {
      _pending = connectivity.whenOnline.listen(
        _online,
        onError: onError,
        cancelOnError: false,
      );
    }
    return state.value;
  }

  Timer _timer;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _retries;
  int _retries;

  Future _online(ConnectivityStatus status) async {
    _pending?.cancel();
    _retries = 0;
    while (_backlog.isNotEmpty) {
      final key = _backlog.first;
      try {
        if (containsKey(key)) {
          final state = getState(key);
          final config = await _push(
            state,
          );
          await commit(
            state.remote(config),
          );
        }
        _backlog.remove(key);
      } on SocketException {
        _retryOnline(status);
      } on Exception catch (error, stackTrace) {
        onError(error, stackTrace);
      }
    }
    if (_backlog.isEmpty) {
      _timer?.cancel();
    }
  }

  void _retryOnline(ConnectivityStatus status) {
    if (connectivity.isOnline) {
      _timer?.cancel();
      _timer = Timer(
        toNextTimeout(_retries, const Duration(seconds: 10)),
        () {
          if (connectivity.isOnline) {
            _online(status);
          }
        },
      );
    }
  }

  /// Get next timeout with exponential backoff
  static Duration toNextTimeout(int retries, Duration maxBackoffTime, {int exponent = 2}) {
    final wait = min(
      pow(exponent, retries++).toInt() + Random().nextInt(1000),
      maxBackoffTime.inMilliseconds,
    );
    return Duration(milliseconds: wait);
  }

  /// Push state to remote
  FutureOr<T> _push(StorageState<T> state) async {
    if (state.isLocal) {
      switch (state.status) {
        case StorageStatus.created:
          return await onCreate(state);
        case StorageStatus.updated:
          return await onUpdate(state);
        case StorageStatus.deleted:
          return await onDelete(state);
      }
      throw RepositoryException('Unable to process $state');
    }
    return state.value;
  }

  @protected
  StorageState<T> validate(StorageState<T> state) {
    final key = toKey(state);
    final previous = containsKey(key) ? _states.get(key) : null;
    switch (state.status) {
      case StorageStatus.created:
        // Not allowed to create same value twice
        if (previous == null || previous.isRemote) {
          return state;
        }
        throw RepositoryStateExistsException(previous, state);
      case StorageStatus.updated:
        if (previous != null) {
          if (!previous.isDeleted) {
            return previous.isRemote ? state : previous.replace(state.value);
          }
          // Not allowed to update deleted state
          throw RepositoryIllegalStateException(previous, state);
        }
        throw RepositoryStateNotExistsException(state);
      case StorageStatus.deleted:
        if (previous == null) {
          throw RepositoryStateNotExistsException(state);
        }
        return state;
    }
    throw RepositoryIllegalStateException(previous, state);
  }

  /// Commit [state] to repository
  Future<bool> commit(StorageState<T> state) async {
    final key = toKey(state);
    final current = _states.get(key);
    if (shouldDelete(next: state, current: current)) {
      await _states.delete(key);
      // Can not logically exist anymore, remove it!
      _backlog.remove(key);
    } else {
      await _states.put(key, state);
    }
    if (!_closed) {
      _controller.add(state);
    }
    return containsKey(key);
  }

  /// Test if given transition should
  /// delete value from repository.
  ///
  /// Value should be delete if and only if
  /// 1) current state origin is remote
  /// 2) current state is created with origin local
  bool shouldDelete({
    StorageState next,
    StorageState current,
  }) =>
      current != null
          ? current.isDeleted && next.isRemote || current.isCreated && current.isLocal && next.isDeleted
          : false;

  /// Replace [state] in repository for given [key]-[value] pair
  Future<StorageState<T>> replace(S key, T value, {bool remote}) async {
    final current = _assertExist(key, value: value);
    final next = current.replace(value, remote: remote);
    await commit(next);
    return next;
  }

  StorageState _assertExist(S key, {T value}) {
    final state = _states.get(key);
    if (state == null) {
      throw RepositoryStateNotExistsException(
        StorageState.created(value),
      );
    }
    return state;
  }

  /// Clear all states from local storage
  Future<Iterable<T>> clear({bool compact = true}) async {
    final Iterable<T> elements = values.toList();
    if (_isReady) {
      if (compact) {
        await _states.compact();
      }
      await _states.clear();
    }
    return List.unmodifiable(elements);
  }

  bool _closed = false;

  void close() {
    _closed = true;
    _timer?.cancel();
    _pending?.pause();
    _controller.close();
  }
}

class RepositoryDelegate {
  /// Called whenever an [error] is thrown in any [ConnectionAwareRepository]
  /// with the given [repo], [error], and [stackTrace].
  /// The [stacktrace] argument may be `null` if the state stream received an error without a [stackTrace].
  @mustCallSuper
  void onError(ConnectionAwareRepository repo, Object error, StackTrace stackTrace) {
    throw RepositoryException('${repo.runtimeType}: $error', stackTrace: stackTrace);
  }
}

/// Oversees all [repositories] and delegates responsibilities to the [RepositoryDelegate].
class RepositorySupervisor {
  /// [RepositoryDelegate] which is notified when events occur in all [bloc]s.
  RepositoryDelegate _delegate = RepositoryDelegate();

  RepositorySupervisor._();

  static final RepositorySupervisor _instance = RepositorySupervisor._();

  /// [RepositoryDelegate] getter which returns the singleton [RepositorySupervisor] instance's [RepositoryDelegate].
  static RepositoryDelegate get delegate => _instance._delegate;

  /// [RepositoryDelegate] setter which sets the singleton [RepositorySupervisor] instance's [RepositoryDelegate].
  static set delegate(RepositoryDelegate d) {
    _instance._delegate = d ?? RepositoryDelegate();
  }
}

class RepositoryException implements Exception {
  final String message;
  final StackTrace stackTrace;
  RepositoryException(this.message, {this.stackTrace});
  @override
  String toString() {
    return '$runtimeType: {message: $message, stackTrace: $stackTrace}';
  }
}

class RepositoryIllegalStateValueException extends RepositoryException {
  final String reason;
  final StorageState state;
  RepositoryIllegalStateValueException([
    this.state,
    this.reason,
  ]) : super('state value [${state.value?.runtimeType} ${state.value}}] is invalid: $reason');
}

class RepositoryNotReadyException extends RepositoryException {
  RepositoryNotReadyException() : super('is not ready');
}

class RepositoryIsClosedException extends RepositoryException {
  RepositoryIsClosedException() : super('is closed');
}

class RepositoryStateExistsException extends RepositoryException {
  final StorageState previous;
  final StorageState next;
  RepositoryStateExistsException(
    this.previous,
    this.next,
  ) : super('state $previous already exists');
}

class RepositoryStateNotExistsException extends RepositoryException {
  final StorageState state;
  RepositoryStateNotExistsException([
    this.state,
  ]) : super('state $state does not exists');
}

class RepositoryIllegalStateException extends RepositoryException {
  final StorageState previous;
  final StorageState next;
  RepositoryIllegalStateException(
    this.previous,
    this.next,
  ) : super('is in illegal state ${previous.status}, next ${next.status} not allowed');
}
