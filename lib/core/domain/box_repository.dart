import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';

import 'models/core.dart';
import 'repository.dart';
import 'box_repository_request_queue.dart';

/// Base class for implementing a stateful
/// repository that is aware of connection
/// status where states are stored locally
/// using Hive.
///
/// Use this class to implement a repository that
/// should cache all changes locally before
/// attempting to [commit] them to a backend API.
///
abstract class BoxRepository<K, T extends JsonObject, U extends Service> implements Repository<K, T> {
  BoxRepository({
    @required this.service,
    @required this.connectivity,
    this.dependencies = const [],
  }) {
    _requestQueue = BoxRepositoryRequestQueue(this, connectivity);
  }

  final U service;
  final ConnectivityService connectivity;
  final Iterable<BoxRepository> dependencies;
  final StreamController<StorageTransition<T>> _controller = StreamController.broadcast();

  /// Box request queue instance
  BoxRepositoryRequestQueue<K, T, U> get requestQueue => _requestQueue;
  BoxRepositoryRequestQueue _requestQueue;

  /// Get aggregate type
  Type get aggregateType => typeOf<T>();

  /// Get stream of state changes
  Stream<StorageTransition<T>> get onChanged => _controller.stream;

  /// Check if repository is empty
  ///
  /// If [isReady] is [true], then [isNotEmpty] is always [false]
  bool get isNotEmpty => !isEmpty;

  /// Check if repository is empty.
  ///
  /// If [isReady] is [true], then [isEmpty] is always [true]
  bool get isEmpty => !isReady || _box.isEmpty;

  /// Get value from [key]
  T operator [](K key) => get(key);

  /// Get number of states
  int get length => isReady ? _box.length : 0;

  /// Check if repository is online
  bool get isOnline => connectivity.isOnline;

  /// Check if repository is offline
  bool get isOffline => connectivity.isOffline;

  /// Find [T]s matching given query
  Iterable<T> find({bool where(T aggregate)}) => isReady ? values.where(where) : [];

  /// Get value from [key]
  T get(K key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(K key) => isReady && _isNotNull(key) && containsKey(key) ? _box?.get(key) : null;
  bool _isNotNull(K key) => key != null;

  /// Get backlog of states pending push to a backend API
  Iterable<K> get backlog => List.unmodifiable(_backlog.keys);
  final _backlog = LinkedHashMap<K, Completer<T>>();

  /// Get [StorageState] with errors
  ///
  /// removed on next successful
  /// [commit] for given state.
  Iterable<StorageState<T>> get errors => isReady ? _box.values.where((state) => state.isError) : [];

  /// Get all states as unmodifiable map
  Map<K, StorageState<T>> get states => Map.unmodifiable(isReady ? _box.toMap() : <K, StorageState<T>>{});

  /// Local state storage [Box]
  Box<StorageState<T>> _box;

  /// Get all (key,value)-pairs as unmodifiable map
  Map<K, T> get map => Map.unmodifiable(isReady ? Map.fromIterables(keys, values) : <K, T>{});

  /// Get all keys as unmodifiable list
  Iterable<K> get keys => List.unmodifiable(isReady ? _box?.keys : []);

  /// Get all values as unmodifiable list
  Iterable<T> get values => List.unmodifiable(isReady ? states.values.map((state) => state.value) : <T>[]);

  /// Check if key exists
  bool containsKey(K key) => isReady ? _box.keys.contains(key) : false;

  /// Check if value exists
  bool containsValue(T value) => isReady ? _box.values.any((state) => state.value == value) : false;

  /// Check if repository is operational
  @mustCallSuper
  bool get isReady => _isReady();
  bool get isNotReady => !_isReady();

  /// Get key [K] from state [T]
  K toKey(StorageState<T> state);

  /// Create value of type [T] from json
  T fromJson(Map<String, dynamic> json);

  /// Get references to dependent aggregates
  ///
  /// Override this to prevent '404 Not Found'
  /// returned by service because dependency
  /// was not found in backend.
  @visibleForOverriding
  Iterable<AggregateRef> toRefs(T value) => value?.props?.whereType<AggregateRef>() ?? [];

  /// Asserts that repository is operational.
  /// Should be called before methods is called.
  /// If not ready an [RepositoryNotReadyException] is thrown
  @protected
  void checkState() {
    if (_box?.isOpen != true) {
      throw RepositoryNotReadyException(this);
    } else if (_disposed) {
      throw RepositoryIsDisposedException(this);
    }
  }

  /// Reads [states] from storage
  @visibleForOverriding
  Future<Iterable<StorageState<T>>> prepare({
    String postfix,
    bool force = false,
    bool compact = false,
  }) async {
    if (force || _box == null) {
      await _requestQueue.cancel();

      if (compact) {
        await _box?.compact();
      }
      _box = await openBox(postfix);

      // Build queue from states
      _requestQueue.build(
        _box.values,
      );
    }
    // Get mapped states
    return states.values;
  }

  @visibleForOverriding
  Future<Box<StorageState<T>>> openBox(String postfix) async {
    return Hive.openBox(
      toBoxName(
        postfix: postfix,
        runtimeType: runtimeType,
      ),
      encryptionKey: await Storage.hiveKey<T>(),
    );
  }

  /// Get future that returns when
  /// [StorageState] for given [key]
  /// changes to remote. If already
  /// remote the future returns directly.
  ///
  /// If [require] is [true] the future
  /// will not return until state for
  /// given [uuid] exist remotely.
  ///
  /// Will throw [RepositoryRemoteException]
  /// if state transitions to error and
  /// [fail] is [true], otherwise future
  /// completes with error state.
  ///
  Future<StorageState<T>> onRemote(
    K key, {
    bool fail = false,
    bool require = true,
  }) async {
    final current = getState(key);
    if (current?.isRemote == true || !require && current == null) {
      return Future.value(current);
    }
    final transition = await onChanged
        .where((transition) => transition.isRemote || transition.isError)
        .where((transition) => toKey(transition.to) == key)
        .firstWhere(
          (transition) => transition.isError || transition.to != null,
          orElse: () => null,
        );
    if (transition != null) {
      final state = transition.to;
      if (fail && transition.isError) {
        throw RepositoryRemoteException(
          'Failed to change state with error ${state.isConflict ? state.conflict.error : state.error}',
          state: state,
          stackTrace: StackTrace.current,
        );
      }
      return state;
    }
    return Future.value();
  }

  /// Is called before create, update and delete to
  /// prevent '404 Not Found' returned by service
  /// because dependency was not found in backend.
  bool shouldWait(K key) => _requestQueue.shouldWait(key);

  /// Get boc
  static String toBoxName<T>({String postfix, Type runtimeType}) =>
      ['${runtimeType ?? typeOf<T>()}', postfix].where((part) => !isEmptyOrNull(part)).join('_');

  /// Check if repository is
  /// loading data from [service].
  bool get isLoading => _requestQueue.isLoading;

  /// Wait on future completed when
  /// loading is finished. If offline
  /// or not loading this future
  /// completes directly.
  ///
  /// Set [waitForOnline] to
  /// [true] to wait until
  /// connectivity is resumed.
  ///
  /// Set [waitFor] to limit the
  /// amount of time to wait until
  /// [values] are returned
  /// regardless of [isLoading].
  ///
  /// Setting [fail] to [true] throws
  /// a [RepositoryTimeoutException]
  /// if [waitForOnline] is [false]
  /// and repository [isOffline], or
  /// if [waitFor] is given and
  /// loading does not complete with
  /// duration given by [waitFor].
  ///
  Future<Iterable<T>> onLoadedAsync({
    Duration waitFor,
    bool fail = false,
    bool waitForOnline = false,
  }) {
    return _requestQueue.onLoadedAsync(
      waitFor: waitFor,
      fail: fail,
      waitForOnline: waitForOnline,
    );
  }

  /// Patch [value] with existing
  /// in repository and replace
  /// current state
  StorageState<T> patch(T value, {bool isRemote = false}) {
    checkState();
    StorageState next = _toState(
      value,
      isRemote,
    );
    return put(_patch(next)) ? next : null;
  }

  StorageState _toState(T value, bool isRemote) {
    final state = StorageState<T>.created(
      value,
      isRemote: isRemote,
    );
    final key = toKey(state);
    assert(key != null, "Key can not be null");
    final next = containsKey(key)
        ? getState(key).apply(
            value,
            isRemote: isRemote,
          )
        : state;
    return next;
  }

  /// Replace [value] with existing in repository
  StorageState<T> replace(T value, {bool isRemote = false}) {
    checkState();
    StorageState next = _toState(
      value,
      isRemote,
    );
    return put(next) ? next : null;
  }

  /// Remove [value] from repository
  StorageState<T> remove(T value, {bool isRemote = false, T previous}) {
    checkState();
    final next = StorageState<T>(
      value: value,
      previous: previous,
      isRemote: isRemote,
      status: StorageStatus.deleted,
    );
    return put(next) ? next : null;
  }

  /// Patch [next] state with existing in repository
  StorageState<T> _patch(StorageState next) {
    final key = toKey(next);
    final current = getState(key);
    return current == null ? next : current.patch<T>(next, fromJson);
  }

  /// Put [state] to repository.
  /// this will overwrite existing
  /// state. Returns [true] if
  /// state exists afterwards,
  /// [false] otherwise.
  bool put(StorageState<T> state) {
    checkState();
    final key = toKey(state);
    assert(key != null, "Key can not be null");
    final current = getState(key);
    if (shouldDelete(next: state, current: current)) {
      _box.delete(key);
      // Can not logically exist
      // anymore, remove it!
      _requestQueue.remove(key);
    } else {
      _box.put(key, state);
    }
    if (!_disposed) {
      _controller.add(StorageTransition<T>(
        from: current,
        to: state,
      ));
    }
    return containsKey(key);
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

  /// Apply [value] an push to [service]
  T apply(
    T value, {
    Completer<T> onResult,
  }) {
    checkState();
    StorageState next = _toState(
      value,
      false,
    );
    return push(
      _patch(next),
      onResult: onResult,
    );
  }

  /// Delete current value
  T delete(
    K key, {
    Completer<T> onResult,
  }) {
    checkState();
    return push(
      StorageState.deleted(this[key]),
      onResult: onResult,
    );
  }

  /// Apply [state] and push to [service]
  @visibleForOverriding
  T push(
    StorageState<T> state, {
    Completer<T> onResult,
  }) {
    checkState();
    final next = validate(state);
    final hasValueChanged = !isValueEqual(next);
    final hasStatusChanged = !isStatusEqual(next);
    final exists = put(next);
    if (exists && (next.isLocal || hasValueChanged || hasStatusChanged)) {
      // Replace current if not executed yet
      return _requestQueue.push(
        toKey(next),
        onResult: onResult,
      );
    }
    return next.value;
  }

  /// Should reset to remote states in [service]
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<Iterable<T>> onReset({Iterable<T> previous});

  /// Should create state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onCreate(StorageState<T> state) => Future.value(state.value);

  /// Should update state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onUpdate(StorageState<T> state) => Future.value(state.value);

  /// Should delete state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onDelete(StorageState<T> state) => Future.value(state.value);

  /// Should resolve conflict
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<T>> onResolve(StorageState<T> state, ServiceResponse response) {
    return MergeStrategy(this)(
      state,
      response.conflict,
    );
  }

  /// Should handle missing dependency.
  ///
  /// Default handling is to return current state.
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<T>> onNotFound(StorageState<T> state, ServiceResponse response) => Future.value(state);

  /// Should handle errors
  @mustCallSuper
  @visibleForOverriding
  void onError(Object error, StackTrace stackTrace) => RepositorySupervisor.delegate.onError(
        this,
        error,
        stackTrace,
      );

  /// Check if in a transaction.
  ///
  /// If [true] repository will
  /// not schedule and process
  /// push requests until [commit]
  /// is called.
  ///
  bool get inTransaction => _inTransaction;
  bool _inTransaction = false;

  /// When in transaction, all
  /// changes are applied locally.
  ///
  /// Calling [commit] will schedule changes
  void beginTransaction() => _inTransaction = true;

  /// Commit local states to backend
  ///
  /// This will set [inTransaction] to false.
  ///
  /// Returns list of keys to committed states.
  ///
  Future<List<K>> commit() async {
    states.forEach((key, state) {
      _requestQueue.stash(
        state,
      );
    });
    _inTransaction = false;
    return _requestQueue.pop();
  }

  //
  // /// Schedule push state to [service]
  // ///
  // /// This method will return before any
  // /// result is received from the [service].
  // ///
  // /// Errors from [service] are handled
  // /// automatically by appropriate actions.
  // @protected
  // T schedulePush(
  //   K key, {
  //   Completer<T> onResult,
  // }) {
  //   // Replace current if not executed yet
  //   return _requestQueue.push(
  //     key,
  //     onResult: onResult,
  //   );
  // }

  bool _isReady() => _box?.isOpen == true && _disposed == false;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _requestQueue.retries;

  @protected
  StorageState<T> validate(StorageState<T> state) {
    final key = toKey(state);
    final previous = isReady ? getState(key) : null;
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

  /// Reset all states to remote state
  Future<Iterable<T>> reset() {
    final previous = clear();
    return onReset(previous: previous);
  }

  /// Clear all states from local storage
  Iterable<T> clear() {
    final Iterable<T> elements = values.toList();
    if (_isReady()) {
      _box.clear();
    }
    return List.unmodifiable(elements);
  }

  /// Evict states from local storage
  Iterable<T> evict({
    bool remote = true,
    bool local = false,
    Iterable<K> retainKeys = const [],
  }) {
    if (remote && local) {
      return clear();
    }
    final List<T> evicted = [];
    if (_isReady()) {
      final keys = [];
      _box.keys.where((key) => !retainKeys.contains(key)).forEach((key) {
        final state = getState(key);
        if (remote && state.isRemote) {
          keys.add(key);
          evicted.add(state.value);
        } else if (local && state.isLocal) {
          keys.add(key);
          evicted.add(state.value);
        }
      });
      _box.deleteAll(keys);
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
    if (_isReady()) {
      await _requestQueue.cancel();
      await _box.close();
    }
    _box = null;
    return List.unmodifiable(elements);
  }

  /// Flag is true after
  /// [dispose] is called.
  bool _disposed = false;

  /// Dispose repository
  ///
  /// After this point it can
  /// not used again.
  Future<void> dispose() async {
    _disposed = true;
    _controller.close();
    _requestQueue?.cancel();
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
    if (_isReady()) {
      await close();
    }
  }

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );
}
