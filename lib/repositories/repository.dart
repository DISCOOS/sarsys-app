import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:SarSys/core/storage.dart';
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
abstract class ConnectionAwareRepository<S, T> {
  ConnectionAwareRepository({
    @required this.connectivity,
    this.compactWhen = 10,
  });
  final int compactWhen;
  final ConnectivityService connectivity;
  final StreamController<StorageState<T>> _controller = StreamController.broadcast();

  /// Get stream of state changes
  Stream<StorageState<T>> get changes => _controller.stream;

  /// Get value from [key]
  T operator [](S key) => _states?.get(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(S key) => _states?.get(key);

  /// Get backlog of states pending push to a backend API
  Iterable<S> get backlog => List.unmodifiable(_backlog);
  final _backlog = ListQueue<S>();

  /// Get all states as unmodifiable map
  Map<S, StorageState<T>> get states => Map.unmodifiable(_states?.toMap() ?? {});
  Box<StorageState<T>> _states;

  /// Get all keys as unmodifiable list
  Iterable<S> get keys => List.unmodifiable(_states?.keys ?? []);

  /// Get all values as unmodifiable list
  Iterable<T> get values => List.unmodifiable(_states?.values?.map((state) => state.value));

  /// Check if key exists
  bool containsKey(S key) => _states?.keys?.contains(key) ?? false;

  /// Check if value exists
  bool containsData(T value) => _states?.values?.any((state) => state.value == value) ?? false;

  /// Check if repository is operational
  @mustCallSuper
  bool get isReady => _states?.isOpen == true;

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
  Future<Iterable<StorageState<T>>> prepare({bool force}) async {
    if (force || _states == null) {
      _states?.close();
      _states = await Hive.openBox(
        '$runtimeType',
        encryptionKey: await Storage.hiveKey<T>(),
        compactionStrategy: (_, deleted) => compactWhen < deleted,
      );
      // Add local states to backlog
      _backlog
        ..clear()
        ..addAll(
          _states.values.where((state) => state.isLocal).map((state) => toKey(state)),
        );
    }
    return states.values;
  }

  /// Apply [state] and push to remote
  @visibleForOverriding
  FutureOr<T> apply(
    StorageState<T> state,
  ) async {
    checkState();
    await commit(state);
    if (!state.isRemote) {
      if (connectivity.isOnline) {
        try {
          final config = await _push(
            state,
          );
          await commit(
            StorageState.remote(config),
          );
          return config;
        } on SocketException {
          // Timeout - try again later
        } on Exception catch (error, stackTrace) {
          onError(error, stackTrace);
        }
      } // if offline or a SocketException was thrown
      return _offline(state);
    } // if state is remote
    return state.value;
  }

  /// Subscription for handling  offline -> online
  StreamSubscription<ConnectivityStatus> _pending;

  T _offline(StorageState<T> state) {
    final key = toKey(state);
    _backlog.add(key);
    _pending ??= connectivity.whenOnline.listen(
      _online,
      onError: onError,
      cancelOnError: false,
    );
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
      final uuid = _backlog.first;
      try {
        final config = await _push(
          getState(uuid),
        );
        await commit(
          StorageState.remote(config),
        );
        _backlog.removeFirst();
      } on SocketException {
        _retryOnline(status);
      } on Exception catch (error, stackTrace) {
        onError(error, stackTrace);
      }
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
    switch (state.status) {
      case StorageStatus.local:
        return await onCreate(state);
      case StorageStatus.changed:
        return await onUpdate(state);
      case StorageStatus.deleted:
        return await onDelete(state);
      case StorageStatus.remote:
        return state.value;
    }
    throw RepositoryException('Unable to process $state');
  }

  /// Commit [state] to repository
  @protected
  Future<T> commit(StorageState<T> state) async {
    final key = toKey(state);
    final current = _states.get(key);
    if (state.isRemote && current.isDeleted) {
      await _states.delete(key);
    } else {
      await _states.put(key, state);
    }
    if (!_closed) {
      _controller.add(state);
    }
    return state.value;
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

class RepositoryNotReadyException extends RepositoryException {
  RepositoryNotReadyException() : super('is not ready');
}

class RepositoryIsClosedException extends RepositoryException {
  RepositoryIsClosedException() : super('is closed');
}
