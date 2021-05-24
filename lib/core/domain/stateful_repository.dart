import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/domain/stateful_merge_strategy.dart';
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
import 'stateful_request_queue.dart';

/// Base class for implementing a stateful
/// repository that is aware of connection
/// status where states are stored locally
/// using Hive.
///
/// Use this class to implement a repository that
/// should cache all changes locally before
/// attempting to [commit] them to a backend API.
///
abstract class StatefulRepository<K, V extends JsonObject, S extends StatefulServiceDelegate<V, V>>
    extends Repository<K, V> {
  StatefulRepository({
    @required this.service,
    @required this.connectivity,
    this.dependencies = const [],
    StorageState<V> Function(StorageState<V> state) onGet,
    void Function(StorageState<V> state, bool isDeleted) onPut,
  })  : _onGet = onGet,
        _onPut = onPut {
    _requestQueue = StatefulRequestQueue(
      this,
      connectivity,
    );
  }

  /// Default timeout on requests that
  /// should return within finite time
  static const Duration timeLimit = const Duration(seconds: 30);

  final S service;
  final ConnectivityService connectivity;
  final Iterable<StatefulRepository> dependencies;
  final StorageState<V> Function(StorageState<V> state) _onGet;
  final void Function(StorageState<V> state, bool isDeleted) _onPut;
  final StreamController<bool> _onReady = StreamController.broadcast();
  final StreamController<StorageTransition<V>> _onTransition = StreamController.broadcast();

  /// Box request queue instance
  StatefulRequestQueue<K, V, S> get requestQueue => _requestQueue;
  StatefulRequestQueue<K, V, S> _requestQueue;

  /// Get aggregate type
  Type get aggregateType => typeOf<V>();

  /// Check if repository is operational
  @mustCallSuper
  bool get isReady => _isReady();
  bool get isNotReady => !_isReady();

  /// Stream of isReady changes
  Stream<bool> get onReadyChanged => _onReady.stream;

  /// Wait on [isReady] is [true]
  Future<bool> get onReady => isReady ? Future.value(true) : onReadyChanged.where((state) => state).first;

  /// Wait on [isReady] is [false]
  Future<bool> get onNotReady => !isReady ? Future.value(false) : onReadyChanged.where((state) => !state).first;

  /// Get stream of state changes
  Stream<StorageTransition<V>> get onChanged => _onTransition.stream;

  /// Check if repository is empty
  ///
  /// If [isReady] is [true], then [isNotEmpty] is always [false]
  bool get isNotEmpty => !isEmpty;

  /// Check if repository is empty.
  ///
  /// If [isReady] is [true], then [isEmpty] is always [true]
  bool get isEmpty => !isReady || _box.isEmpty;

  /// Get value from [key]
  V operator [](K key) => get(key);

  /// Get number of states
  int get length => isReady ? _box.length : 0;

  /// Check if repository is online
  bool get isOnline => connectivity.isOnline;

  /// Check if repository is offline
  bool get isOffline => connectivity.isOffline;

  /// Find [V]s matching given query
  Iterable<V> find({bool where(V value)}) => isReady ? values.where(where) : [];

  /// Get value from [key]
  V get(K key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<V> getState(K key) {
    var state;
    if (isReady && _isNotNull(key) && containsKey(key)) {
      state = _box?.get(key);
      if (_onGet != null) {
        state = _onGet(state);
      }
    }
    return state;
  }

  bool _isNotNull(K key) => key != null;

  /// Get backlog of states pending push to a backend API
  Iterable<K> get backlog => _requestQueue.backlog;

  /// Get [StorageState] with errors
  ///
  /// removed on next successful
  /// [commit] for given state.
  Iterable<StorageState<V>> get errors => isReady ? _box.values.where((state) => state.isError) : [];

  /// Get all states as unmodifiable map
  Map<K, StorageState<V>> get states => Map.unmodifiable(isReady ? _box.toMap() : <K, StorageState<V>>{});

  /// Local state storage [Box]
  Box<StorageState<V>> _box;

  /// Get all (key,value)-pairs as unmodifiable map
  Map<K, V> get map => Map.unmodifiable(isReady ? Map.fromIterables(keys, values) : <K, V>{});

  /// Get all keys as unmodifiable list
  Iterable<K> get keys => List.unmodifiable(isReady ? _box?.keys : []);

  /// Get all values as unmodifiable list
  Iterable<V> get values => List.unmodifiable(keys.map((key) => getState(key).value));

  /// Check if key exists
  bool containsKey(K key) => isReady ? _box.keys.contains(key) : false;

  /// Check if value exists
  bool containsValue(V value) => isReady ? _box.keys.any((key) => getState(toKey(value)).value == value) : false;

  /// Get key [K] from value [V]
  K toKey(V value);

  /// Create value of type [V] from json
  V fromJson(Map<String, dynamic> json);

  /// Get [StateVersion] for key [K]
  StateVersion getVersion(K key) => containsKey(key) ? getState(key).version : StateVersion.none;

  /// Get next expected version
  StateVersion nextVersion(K key) => containsKey(key) ? getState(key).version + 1 : StateVersion.first;

  /// Get references to dependent aggregates
  ///
  /// Override this to prevent '404 Not Found'
  /// returned by service because dependency
  /// was not found in backend.
  @visibleForOverriding
  Iterable<AggregateRef> toRefs(V value) => value?.props?.whereType<AggregateRef>() ?? [];

  /// Asserts that repository is operational.
  /// Should be called before methods is called.
  /// If not ready an [RepositoryNotReadyException] is thrown
  @protected
  void checkState() {
    if (_box?.isOpen != true) {
      throw RepositoryNotReadyException(this);
    } else if (_isDisposed) {
      throw RepositoryIsDisposedException(this);
    }
  }

  /// Reads [states] from storage
  @visibleForOverriding
  Future<Iterable<StorageState<V>>> prepare({
    String postfix,
    bool force = false,
    bool compact = false,
  }) async {
    if (force || _box == null) {
      await _requestQueue.cancel();

      if (compact) {
        await _box?.compact();
      }
      if (_isReady()) {
        await _closeBox();
        if (_isDisposed) {
          return [];
        }
        _onReady.add(false);
      }

      // Open box with given prefix
      _box = await openBox(postfix);
      if (_isDisposed) {
        await _closeBox();
        return [];
      }
      _onReady.add(true);

      // Build queue from states
      _requestQueue.build(
        _box.values,
      );
    }
    // Get mapped states
    return states.values;
  }

  @visibleForOverriding
  Future<Box<StorageState<V>>> openBox(String postfix) async {
    return Hive.openBox(
      toBoxName(
        postfix: postfix,
        runtimeType: runtimeType,
      ),
      encryptionCipher: await Storage.hiveCipher<V>(),
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
  /// If no result is given within
  /// given [waitFor] this method will
  /// return current state to prevent
  /// buildup of waiting futures.
  ///
  Future<StorageState<V>> onRemote(
    K key, {
    bool fail = false,
    bool require = true,
    bool waitForOnline = false,
    Duration waitFor = timeLimit,
  }) async {
    final current = getState(key);
    if (current?.isRemote == true || !require && current == null || isOffline && !waitForOnline) {
      return Future.value(current);
    }
    try {
      final transition = await onChanged
          .where((transition) => transition.isRemote || transition.isError || transition.isDeleted)
          .where((transition) => toKey(transition.to.value) == key)
          .firstWhere(
            (transition) => transition.isError || transition.to != null || transition.isDeleted,
            orElse: () => null,
          )
          .timeout(waitFor);
      if (transition != null) {
        final state = transition.to;
        if (fail && transition.isError) {
          throw RepositoryRemoteException(
            'Failed to change state with error ${state.isConflict ? state.conflict.error : state.error}',
            this,
            state: state,
            stackTrace: StackTrace.current,
          );
        }
        return state;
      }
      return Future.value(current);
    } on TimeoutException {
      if (fail) {
        rethrow;
      }
      return Future.value(current);
    }
  }

  /// Is called before create, update and delete to
  /// prevent '404 Not Found' returned by service
  /// because dependency was not found in backend.
  bool shouldWait(K key) => _requestQueue.shouldWait(key);

  /// Get boc
  static String toBoxName<V>({String postfix, Type runtimeType}) =>
      ['${runtimeType ?? typeOf<V>()}', postfix].where((part) => !isEmptyOrNull(part)).join('_');

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
  Future<Iterable<V>> onLoadedAsync({
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

  /// Patch [value] with existing in repository
  /// and replace current state. This method
  /// does not push changes to [service].
  StorageState<V> patch(
    V value, {
    bool isRemote = false,
    StateVersion version,
  }) {
    checkState();
    var next = _toState(
      value,
      replace: false,
      version: version,
      isRemote: isRemote,
    );
    // If state was deleted, null is returned
    return put(_patch(next)) ? next : null;
  }

  StorageState<V> _toState(
    V value, {
    @required bool replace,
    @required bool isRemote,
    Object error,
    StateVersion version,
  }) {
    final key = toKey(value);
    final state = getState(key);
    assert(key != null, "Key can not be null");
    final next = containsKey(key)
        ? state.apply(
            value,
            error: error,
            replace: replace,
            version: version,
            isRemote: isRemote,
          )
        : state;
    return next ??
        StorageState.created(
          value,
          version ?? StateVersion.first,
        );
  }

  /// Replace [value] with existing in repository
  /// and replace current state. This method
  /// does not push changes to [service].
  StorageState<V> replace(V value, {bool isRemote = false}) {
    checkState();
    StorageState next = _toState(
      value,
      replace: true,
      isRemote: isRemote,
    );
    return put(next) ? next : null;
  }

  /// Remove [value] from repository. This
  /// method does not push changes to [service].
  StorageState<V> remove(V value, {bool isRemote = false, V previous}) {
    checkState();
    final key = toKey(value);
    final next = StorageState<V>(
      value: value,
      previous: previous,
      isRemote: isRemote,
      version: nextVersion(key),
      status: StorageStatus.deleted,
    );
    return put(next) ? next : null;
  }

  /// Patch [next] state with existing in repository
  StorageState<V> _patch(StorageState next) {
    final key = toKey(next.value);
    final current = getState(key);
    return current == null ? next : current.patch<V>(next, fromJson);
  }

  /// Wait for these on close
  /// to prevent box corruption
  final List<Future> _writes = <Future>[];

  /// Put [state] to repository.
  /// this will overwrite existing
  /// state. Returns [true] if
  /// state exists afterwards,
  /// [false] otherwise. This method
  /// does not push changes to
  /// [service].
  bool put(StorageState<V> state) {
    checkState();
    final key = toKey(state.value);
    assert(key != null, "Key can not be null");
    if (!isStateEqual(state)) {
      final current = getState(key);
      final delete = shouldDelete(
        next: state,
        current: current,
      );
      if (delete) {
        _onWrite(
          _box.delete(key),
        );
        // Can not logically exist
        // anymore, remove it!
        _requestQueue.remove(key);
      } else {
        _onWrite(
          _box.put(key, state),
        );
      }
      if (_onPut != null) {
        _onPut(state, delete);
      }
      if (!_isDisposed) {
        _onTransition.add(StorageTransition<V>(
          from: current,
          to: state,
        ));
      }
    }
    return containsKey(key);
  }

  void _onWrite(Future write) {
    _writes.add(write);
    write.whenComplete(
      () => _writes.remove(write),
    );
  }

  /// Check if [StorageState.value] of given [state]
  /// is equal to value in current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isValueEqual(StorageState<V> state) {
    final current = get(toKey(state.value));
    return current != null && current == state.value;
  }

  /// Check if [StorageState.status] of given [state]
  /// is equal to value in current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isStatusEqual(StorageState<V> state) {
    final current = getState(toKey(state.value));
    return current != null && current.status == state.status;
  }

  /// Check if [StorageState.isRemote] of given [state]
  /// is equal to value in current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isOriginEqual(StorageState<V> state) {
    final current = getState(toKey(state.value));
    return current != null && current.isRemote == state.isRemote;
  }

  /// Check if given [state] is to current state if exists.
  ///
  /// Returns false if current state does not exists
  ///
  bool isStateEqual(StorageState<V> state) {
    final current = getState(toKey(state.value));
    return current != null &&
        current.value == state.value &&
        current.error == state.error &&
        current.status == state.status &&
        current.version == state.version &&
        current.isRemote == state.isRemote;
  }

  /// Apply [value] an push to [service]
  V apply(
    V value, {
    Completer<V> onResult,
  }) {
    checkState();
    StorageState<V> next = _toState(
      value,
      replace: false,
      isRemote: false,
    );
    return push(
      _patch(next),
      onResult: onResult,
    );
  }

  /// Delete current value an push to [service]
  V delete(
    K key, {
    Completer<V> onResult,
  }) {
    checkState();
    return push(
      StorageState.deleted(
        this[key],
        nextVersion(key),
      ),
      onResult: onResult,
    );
  }

  /// Write given [state] to local storage
  /// and push to [service] if value was
  /// changed.
  @visibleForOverriding
  V push(
    StorageState<V> state, {
    Completer<V> onResult,
  }) {
    checkState();
    final next = validate(state);
    final hasChanged = !isStateEqual(next);
    final exists = put(next);
    // If state does not exist after
    // put, it implies that it also
    // is deleted REMOTELY and should
    // therefore not be scheduled!
    if (exists && hasChanged) {
      // Replace current if not executed yet
      return _requestQueue.push(
        toKey(next.value),
        onResult: onResult,
      );
    }
    return next.value;
  }

  /// Should reset to remote states in [service]
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<Iterable<V>> onReset({Iterable<V> previous});

  /// Should create state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<V>> onCreate(StorageState<V> state) => Future.value(state);

  /// Should update state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<V>> onUpdate(StorageState<V> state) => Future.value(state);

  /// Should delete state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<V>> onDelete(StorageState<V> state) => Future.value(state);

  /// Should resolve conflict
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<StorageState<V>> onResolve(StorageState<V> state, ServiceResponse response) {
    return StatefulMergeStrategy(this)(
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
  Future<StorageState<V>> onNotFound(StorageState<V> state, ServiceResponse response) => Future.value(state);

  /// Should handle errors
  @mustCallSuper
  @visibleForOverriding
  void onError(Object error, StackTrace stackTrace) => RepositorySupervisor.delegate.onError(this, error, stackTrace);

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

  bool _isReady() => _box?.isOpen == true && _isDisposed == false;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _requestQueue.retries;

  @protected
  StorageState<V> validate(StorageState<V> state) {
    final key = toKey(state.value);
    final previous = isReady ? getState(key) : null;
    switch (state.status) {
      case StorageStatus.created:
        // Not allowed to create same value twice remotely
        if (previous == null || previous.isLocal) {
          return state;
        }
        throw RepositoryStateExistsException(previous, state, this);
      case StorageStatus.updated:
        if (previous != null) {
          if (!previous.isDeleted) {
            return previous.isRemote ? state : previous.replace(state.value);
          }
          // Not allowed to update deleted state
          throw RepositoryIllegalStateException(previous, state, this);
        }
        throw RepositoryStateNotExistsException(this, state);
      case StorageStatus.deleted:
        if (previous == null) {
          throw RepositoryStateNotExistsException(this, state);
        }
        return state;
    }
    throw RepositoryIllegalStateException(previous, state, this);
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
  Future<Iterable<V>> reset() {
    final previous = clear();
    return onReset(previous: previous);
  }

  /// Clear all states from local storage
  Iterable<V> clear() {
    final Iterable<V> elements = values.toList();
    if (_isReady()) {
      _onWrite(
        _box.clear(),
      );
    }
    return List.unmodifiable(elements);
  }

  /// Evict states from local storage
  Iterable<V> evict({
    bool remote = true,
    bool local = false,
    Iterable<K> retainKeys = const [],
  }) {
    if (remote && local) {
      return clear();
    }
    final List<V> evicted = [];
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
      _onWrite(
        _box.deleteAll(keys),
      );
    }
    return List.unmodifiable(evicted);
  }

  /// Close repository.
  ///
  /// All cached keys and values will be
  /// dropped from memory and local file
  /// is closed after all active read and
  /// write operations finished.
  Future<List<V>> close() async {
    final Iterable<V> elements = values.toList();
    if (_isReady()) {
      await _requestQueue.cancel();
      await _closeBox();
      if (!_isDisposed) {
        _onReady.add(false);
      }
    }
    _box = null;
    return List.unmodifiable(elements);
  }

  Future _closeBox() async {
    if (_box?.isOpen == true) {
      // Prevents box corruption
      await Future.wait(_writes);
      await _box.close();
      _writes.clear();
    }
  }

  /// Flag is true after
  /// [dispose] is called.
  bool _isDisposed = false;

  /// Dispose repository
  ///
  /// After this point it can
  /// not used again.
  Future<void> dispose() async {
    _isDisposed = true;
    if (_isReady()) {
      await close();
    }
    _onReady.close();
    _onTransition.close();
    _requestQueue?.cancel();
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
  }

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );
}
