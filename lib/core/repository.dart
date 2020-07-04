import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/service.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'data/models/conflict_model.dart';

/// Base class for implementing a stateful
/// repository that is aware of connection status.
///
/// Use this class to implement a repository that
/// should cache all changes locally before
/// attempting to [commit] them to a backend API.
///
abstract class ConnectionAwareRepository<S, T extends Aggregate, U extends Service> {
  ConnectionAwareRepository({
    @required this.service,
    @required this.connectivity,
  });
  final U service;
  final ConnectivityService connectivity;
  final StreamController<StorageTransition<T>> _controller = StreamController.broadcast();

  /// Get stream of state changes
  Stream<StorageTransition<T>> get onChanged => _controller.stream;

  /// Check if repository is empty
  ///
  /// If [isReady] is [true], then [isNotEmpty] is always [false]
  bool get isNotEmpty => !isEmpty;

  /// Check if repository is empty.
  ///
  /// If [isReady] is [true], then [isEmpty] is always [true]
  bool get isEmpty => !isReady || _states.isEmpty;

  /// Get value from [key]
  T operator [](S key) => get(key);

  /// Get number of states
  int get length => isReady ? _states.length : 0;

  /// Check if repository is online
  get isOnline => _shouldSchedule();

  /// Check if repository is offline
  get isOffline => connectivity.isOffline;

  /// Find [T]s matching given query
  Iterable<T> find({bool where(T aggregate)}) => isReady ? values.where(where) : [];

  bool _inTransaction = false;
  bool get inTransaction => _inTransaction;

  /// When in transaction, all
  /// changes are applied locally.
  ///
  /// Calling [commit] will schedule changes
  void beginTransaction() => _inTransaction = true;

  /// Commit local states to backend
  ///
  /// This will set [inTransaction] to false.
  ///
  /// Returns list of committed states.
  ///
  Future<List<S>> commit() async {
    _inTransaction = false;
    states.forEach((key, state) {
      if (state.isLocal) {
        _offline(state);
      }
    });
    return _shouldSchedule() ? _online(connectivity.status) : <S>[];
  }

  /// Get value from [key]
  T get(S key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(S key) => isReady && _isNotNull(key) ? _states?.get(key) : null;
  bool _isNotNull(S key) => key != null;

  /// Get backlog of states pending push to a backend API
  Iterable<S> get backlog => List.unmodifiable(_backlog);
  final _backlog = LinkedHashSet();

  /// Get [StorageState] with errors
  ///
  /// removed on next successful
  /// [commit] for given state.
  Iterable<StorageState<T>> get errors => isReady ? _states.values.where((state) => state.isError) : [];

  /// Get all states as unmodifiable map
  Map<S, StorageState<T>> get states => Map.unmodifiable(isReady ? _states?.toMap() : {});
  Box<StorageState<T>> _states;

  /// Get all (key,value)-pairs as unmodifiable map
  Map<S, T> get map => Map.unmodifiable(isReady
      ? Map.fromIterables(
          _states?.keys,
          _states?.values?.map(
            (s) => s.value,
          ))
      : {});

  /// Get all keys as unmodifiable list
  Iterable<S> get keys => List.unmodifiable(isReady ? _states?.keys : []);

  /// Get all values as unmodifiable list
  Iterable<T> get values => List.unmodifiable(isReady ? _states?.values?.map((state) => state.value) : []);

  /// Check if key exists
  bool containsKey(S key) => isReady ? _states.keys.contains(key) : false;

  /// Check if value exists
  bool containsValue(T value) => isReady ? _states.values.any((state) => state.value == value) : false;

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
    } else if (_disposed) {
      throw RepositoryIsDisposedException();
    }
  }

  /// Get key [S] from state [T]
  S toKey(StorageState<T> state);

  /// Should reset to remote states in backend
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<Iterable<T>> onReset();

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
  @mustCallSuper
  @visibleForOverriding
  void onError(
    Object error,
    StackTrace stackTrace,
  ) {
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
      _states = await Hive.openBox(
        toBoxName(postfix: postfix, runtimeType: runtimeType),
        encryptionKey: await Storage.hiveKey<T>(),
      );
      // Add local states to backlog
      _backlog
        ..clear()
        ..addAll(
          _states.values.where((state) => state.isCreated).map((state) => toKey(state)),
        );
    }
    return _states.values;
  }

  /// Get boc
  static String toBoxName<T>({String postfix, Type runtimeType}) =>
      ['${runtimeType ?? typeOf<T>()}', postfix].where((part) => !isEmptyOrNull(part)).join('_');

  /// Apply [next] and [commit] to remote
  @visibleForOverriding
  FutureOr<T> apply(StorageState<T> state) async {
    checkState();
    final next = validate(state);
    final hasValueChanged = !isValueEqual(next);
    final hasStatusChanged = !isStatusEqual(next);
    final exists = put(next);
    if (exists && (hasValueChanged || hasStatusChanged)) {
      return schedule(next);
    }
    return next.value;
  }

  /// Check if [StorageState.value] of given [state]
  /// is equal to value in current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isValueEqual(StorageState<T> state) {
    final current = get(toKey(state));
    return current != null && current == state.value;
  }

  /// Check if [StorageState.status] of given [state]
  /// is equal to value in current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isStatusEqual(StorageState<T> state) {
    final current = getState(toKey(state));
    return current != null && current.status == state.status;
  }

  /// Queue of [StorageState] processed in FIFO manner.
  ///
  /// This queue ensures that each [StorageState] is
  /// processed in order waiting for it to complete of
  /// fail. This prevents concurrent writes which will
  /// result in an unexpected behaviour due to race
  /// conditions.
  final _pushQueue = ListQueue<StorageState<T>>();

  /// Schedule push state to backend
  ///
  /// This method will return before any
  /// result is received from the backend.
  ///
  /// Errors from backend are handled
  /// automatically by appropriate actions.
  Future<T> schedule(StorageState<T> next) async {
    if (next.isLocal) {
      if (_shouldSchedule()) {
        if (_pushQueue.isEmpty) {
          // Process LATER but BEFORE any asynchronous
          // events like Future, Timer or DOM Event
          scheduleMicrotask(_process);
        }
        _pushQueue.add(next);
        return next.value;
      }
      return _offline(next);
    }
    return next.value;
  }

  /// Process [StorageState] in FIFO-manner
  /// until [_pushQueue] is empty.
  Future _process() async {
    while (_pushQueue.isNotEmpty) {
      final next = _pushQueue.first;
      try {
        final result = await _push(
          next,
        );
        put(result);
      } on SocketException {
        // Timeout - try again later
        _offline(next);
      } on Exception catch (error, stackTrace) {
        put(next.failed(error));
        onError(error, stackTrace);
      }
      _pushQueue.removeFirst();
    }
  }

  bool _shouldSchedule() => connectivity.isOnline && !_inTransaction;

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

  Future<List<S>> _online(ConnectivityStatus status) async {
    _pending?.cancel();
    _retries = 0;
    final pushed = <S>[];
    while (_backlog.isNotEmpty) {
      final key = _backlog.first;
      final state = getState(key);
      try {
        if (state != null) {
          final result = await _push(
            state,
          );
          put(result);
          pushed.add(key);
        }
        _backlog.remove(key);
      } on SocketException {
        _retryOnline(status);
      } on Exception catch (error, stackTrace) {
        _backlog.remove(key);
        put(state.failed(error));
        onError(error, stackTrace);
      }
    }
    if (_backlog.isEmpty) {
      _timer?.cancel();
    }
    return pushed;
  }

  void _retryOnline(ConnectivityStatus status) {
    if (_shouldSchedule()) {
      _timer?.cancel();
      _timer = Timer(
        toNextTimeout(_retries, const Duration(seconds: 10)),
        () {
          if (_shouldSchedule()) {
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
  FutureOr<StorageState<T>> _push(StorageState<T> state) async {
    if (state.isLocal) {
      switch (state.status) {
        case StorageStatus.created:
          return StorageState.created(
            await onCreate(state),
            remote: true,
          );
        case StorageStatus.updated:
          return StorageState.updated(
            await onUpdate(state),
            remote: true,
          );
        case StorageStatus.deleted:
          return StorageState.deleted(
            await onDelete(state),
            remote: true,
          );
      }
      throw RepositoryException('Unable to process $state');
    }
    return state;
  }

  @protected
  StorageState<T> validate(StorageState<T> state) {
    final key = toKey(state);
    final previous = isReady ? _states.get(key) : null;
    switch (state.status) {
      case StorageStatus.created:
        // Not allowed to create same value twice remotely
        if (previous == null || previous.isLocal) {
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
  bool put(StorageState<T> state) {
    checkState();
    final key = toKey(state);
    final current = _states.get(key);
    if (shouldDelete(next: state, current: current)) {
      _states.delete(key);
      // Can not logically exist anymore, remove it!
      _backlog.remove(key);
    } else {
      _states.put(key, state);
    }
    if (!_disposed) {
      _controller.add(StorageTransition<T>(
        from: current,
        to: state,
      ));
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
  StorageState<T> replace(S key, T value, {bool remote}) {
    final current = _assertExist(key, value: value);
    final next = current.replace(value, remote: remote);
    put(next);
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

  /// Reset all states to remote state
  Future<Iterable<T>> reset() {
    clear();
    return onReset();
  }

  /// Clear all states from local storage
  Iterable<T> clear() {
    final Iterable<T> elements = values.toList();
    if (_states?.isOpen == true) {
      _states.clear();
    }
    return List.unmodifiable(elements);
  }

  /// Evict states from local storage
  Iterable<T> evict({
    bool remote = true,
    bool local = false,
    Iterable<String> retainKeys = const [],
  }) {
    if (remote && local) {
      return clear();
    }
    final List<T> evicted = [];
    if (_states?.isOpen == true) {
      final keys = [];
      _states.keys.where((key) => !retainKeys.contains(key)).forEach((key) {
        final state = _states.get(key);
        if (remote && state.isRemote) {
          keys.add(key);
          evicted.add(_states.get(key).value);
        } else if (local && state.isLocal) {
          keys.add(key);
          evicted.add(_states.get(key).value);
        }
      });
      _states.deleteAll(keys);
    }
    return List.unmodifiable(evicted);
  }

  /// Close repository.
  ///
  /// All cached keys and values will be
  /// dropped from memory and local file
  /// is closed after all active read and
  /// write operations finished.
  Future<List<T>> close() async {
    final Iterable<T> elements = values.toList();
    if (_states?.isOpen == true) {
      await _states.close();
    }
    _states = null;
    return List.unmodifiable(elements);
  }

  bool _disposed = false;

  /// Dispose repository
  ///
  /// After this point it can
  /// not used again.
  Future dispose() async {
    _disposed = true;
    _controller.close();
    _timer?.cancel();
    _pending?.cancel();
    _timer = null;
    _pending = null;
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
    if (_states?.isOpen == true) {
      return _states.close();
    }
    return Future.value();
  }

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );
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

class MergeStrategy<S, T extends Aggregate, U extends Service> {
  MergeStrategy(this.repository);
  final ConnectionAwareRepository<S, T, U> repository;

  Future<T> call(
    StorageState<T> state,
    ConflictModel conflict,
  ) =>
      reconcile(state, conflict);

  Future<T> reconcile(
    StorageState<T> state,
    ConflictModel conflict,
  ) async {
    switch (conflict.type) {
      case ConflictType.exists:
        return onExists(conflict, state);
      case ConflictType.merge:
        return onMerge(conflict, state);
      case ConflictType.deleted:
        return onDeleted(conflict, state);
    }
    throw UnimplementedError(
      "Reconciling conflict type '${enumName(conflict.type)}' not implemented",
    );
  }

  Future<T> onExists(ConflictModel conflict, StorageState<T> state) {
    // TODO: Manual merge required, default to last writer wins with "mine" now
    return repository.onUpdate(state);
  }

  Future<T> onMerge(ConflictModel conflict, StorageState<T> state) => throw UnimplementedError(
        "Reconciling conflict type 'merge' not implemented",
      );
  Future<T> onDeleted(ConflictModel conflict, StorageState<T> state) => throw UnimplementedError(
        "Reconciling conflict type 'deleted' not implemented",
      );
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

class RepositoryIsDisposedException extends RepositoryException {
  RepositoryIsDisposedException() : super('is disposed');
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
