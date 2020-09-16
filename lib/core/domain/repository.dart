import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// To be used together with [RepositoryProvider]
abstract class Repository {}

/// Base class for implementing a stateful
/// repository that is aware of connection status.
///
/// Use this class to implement a repository that
/// should cache all changes locally before
/// attempting to [commit] them to a backend API.
///
abstract class ConnectionAwareRepository<K, T extends Aggregate, U extends Service> implements Repository {
  ConnectionAwareRepository({
    @required this.service,
    @required this.connectivity,
    this.dependencies = const [],
  });

  final U service;
  final ConnectivityService connectivity;
  final Iterable<ConnectionAwareRepository> dependencies;
  final StreamController<StorageTransition<T>> _controller = StreamController.broadcast();

  /// Get aggregate type
  Type get aggregateType => typeOf<T>();

  /// Get stream of state changes
  Stream<StorageTransition<T>> get onChanged => _controller.stream;

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

  /// Invoked before each [get].
  void onValue({T onGet(T value)}) => _onGet = onGet;
  T Function(T value) _onGet;

  /// Check if repository is empty
  ///
  /// If [isReady] is [true], then [isNotEmpty] is always [false]
  bool get isNotEmpty => !isEmpty;

  /// Check if repository is empty.
  ///
  /// If [isReady] is [true], then [isEmpty] is always [true]
  bool get isEmpty => !isReady || _states.isEmpty;

  /// Get value from [key]
  T operator [](K key) => get(key);

  /// Get number of states
  int get length => isReady ? _states.length : 0;

  /// Check if repository is online
  bool get isOnline => _shouldSchedulePush();

  /// Check if repository is offline
  bool get isOffline => connectivity.isOffline;

  /// Find [T]s matching given query
  Iterable<T> find({bool where(T aggregate)}) => isReady ? values.where(where) : [];

  /// Get value from [key]
  T get(K key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(K key) =>
      isReady && _isNotNull(key) && containsKey(key) ? _StorageState<T>(_toValue, _states?.get(key)) : null;
  bool _isNotNull(K key) => key != null;

  /// Get backlog of states pending push to a backend API
  Iterable<K> get backlog => List.unmodifiable(_backlog);
  final _backlog = LinkedHashSet();

  /// Get [StorageState] with errors
  ///
  /// removed on next successful
  /// [commit] for given state.
  Iterable<StorageState<T>> get errors => isReady ? _states.values.where((state) => state.isError) : [];

  /// Get all states as unmodifiable map
  Map<K, StorageState<T>> get states => Map.unmodifiable(
        isReady
            ? _states.toMap().map((key, value) => MapEntry(key, _StorageState<T>(_toValue, value)))
            : <K, StorageState<T>>{},
      );

  T _toValue(T value) {
    return _onGet == null ? value : _onGet(value);
  }

  Box<StorageState<T>> _states;

  /// Get all (key,value)-pairs as unmodifiable map
  Map<K, T> get map => Map.unmodifiable(isReady ? Map.fromIterables(keys, values) : <K, T>{});

  /// Get all keys as unmodifiable list
  Iterable<K> get keys => List.unmodifiable(isReady ? _states?.keys : []);

  /// Get all values as unmodifiable list
  Iterable<T> get values => List.unmodifiable(isReady ? states.values.map((state) => state.value) : <T>[]);

  /// Check if key exists
  bool containsKey(K key) => isReady ? _states.keys.contains(key) : false;

  /// Check if value exists
  bool containsValue(T value) => isReady ? _states.values.any((state) => state.value == value) : false;

  /// Check if repository is operational
  @mustCallSuper
  bool get isReady => _isReady();
  bool get isNotReady => !_isReady();

  /// Check if load or push requests are pending
  bool get isPending => _loadQueue.isEmpty && _pushQueue.isEmpty;

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
    if (_states?.isOpen != true) {
      throw RepositoryNotReadyException(this);
    } else if (_disposed) {
      throw RepositoryIsDisposedException(this);
    }
  }

  /// Is called before create, update and delete to
  /// prevent '404 Not Found' returned by service
  /// because dependency was not found in backend.
  @protected
  bool shouldWait(K key) {
    final state = getState(key);
    if (state?.isLocal == true) {
      final refs = toRefs(state.value);
      return refs.any(_isRefLocal);
    }
    return false;
  }

  /// Check if reference exists local only
  bool _isRefLocal(AggregateRef ref) {
    final state = dependencies
        .where((dep) => dep.containsKey(ref.uuid))
        .map((dep) => dep.getState(ref.uuid))
        .where((state) => state?.value?.runtimeType == ref.type)
        .firstOrNull;
    if (state != null) {
      return state.isCreated && state.isLocal;
    }
    return false;
  }

  /// Get boc
  static String toBoxName<T>({String postfix, Type runtimeType}) =>
      ['${runtimeType ?? typeOf<T>()}', postfix].where((part) => !isEmptyOrNull(part)).join('_');

  /// Check if given error should move queue to idle state
  bool _shouldStop(Object error, StackTrace stackTrace) {
    final idle = error is SocketException || error is ClientException || error is TimeoutException || isOffline;
    if (idle) {
      _popWhenOnline();
    } else {
      onError(error, stackTrace);
    }
    return idle;
  }

  /// Check if repository is
  /// loading data from [service].
  bool get isLoading => _loadQueue.isNotEmpty;

  Completer<Iterable<T>> _onLoaded;

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
    if (_onLoaded?.isCompleted == false) {
      return _onLoaded.future;
    }

    _onLoaded = Completer<Iterable<T>>();
    _awaitLoaded(
      _onLoaded,
      waitFor,
      waitForOnline,
      fail,
    );
    return _onLoaded.future;
  }

  void _awaitLoaded(Completer<Iterable<T>> completer, Duration waitFor, bool waitForOnline, bool fail) async {
    // Only wait if loading with connectivity
    // online, or wait for online is requested
    if (_shouldWait(waitForOnline)) {
      await Future.delayed(waitFor ?? Duration(milliseconds: 50));
    }

    if (_shouldWait(waitForOnline)) {
      if (fail) {
        completer.completeError(
          RepositoryTimeoutException(
            "Waiting on $runtimeType to complete async loads failed",
          ),
          StackTrace.current,
        );
      } else {
        _awaitLoaded(completer, waitFor, waitForOnline, fail);
      }
    } else if (!completer.isCompleted) {
      assert(!_shouldWait(waitForOnline), "Should not be loading when online");
      completer.complete(values);
    }
  }

  bool _shouldWait(bool waitForOnline) => isLoading && (isOnline || isOffline && waitForOnline);

  /// Queue of [scheduleLoad] processed in FIFO manner.
  ///
  /// This queue ensures that each [load] is
  /// processed in order waiting for it to
  /// complete or fail.
  StreamRequestQueue<Iterable<T>> _loadQueue;

  /// Get local values and schedule a deferred load request
  @protected
  Iterable<T> scheduleLoad(
    AsyncValueGetter<ServiceResponse<Iterable<T>>> request, {
    bool fail = false,
    int maxAttempts = 3,
    bool shouldEvict = true,
    Completer<Iterable<T>> onResult,
  }) {
    // Replace current if not executed yet
    _loadQueue.only(StreamRequest<Iterable<T>>(
      fail: fail,
      onResult: onResult,
      execute: () => _executeLoad(
        request,
        shouldEvict,
      ),
      maxAttempts: maxAttempts,
      fallback: () => Future.value(values),
    ));

    if (isOffline) {
      _loadQueue.stop();
      _pushQueue.stop();
      _popWhenOnline();
    }

    return values;
  }

  Future<StreamResult<Iterable<T>>> _executeLoad(
    AsyncValueGetter<ServiceResponse<Iterable<T>>> request,
    bool shouldEvict,
  ) async {
    var response = await request();
    if (isReady && (response.is200 || response.is206)) {
      final states = response.body.map((value) {
        return StorageState.updated(
          value,
          isRemote: true,
        );
      });
      if (shouldEvict) {
        evict(
          retainKeys: states.map(toKey),
        );
      }
      states.forEach(
        (state) {
          if (toKey(state) != null) {
            put(_patch(state));
          }
        },
      );
    } else if (response.isErrorCode) {
      return StreamResult<Iterable<T>>(
        error: RepositoryServiceException(
          'Failed to load $request',
          response,
        ),
        stackTrace: response.stackTrace,
      );
    }
    return StreamResult<Iterable<T>>(
      value: values,
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
  StorageState<T> remove(T value, {bool isRemote = false}) {
    checkState();
    final next = StorageState<T>(
      value: value,
      isRemote: isRemote,
      status: StorageStatus.deleted,
    );
    return put(next) ? next : null;
  }

  /// Patch [next] state with existing in repository
  StorageState<T> _patch(StorageState next) {
    final key = toKey(next);
    final current = getState(key);
    if (current != null) {
      final patches = JsonUtils.diff(current.value, next.value);
      if (patches.isNotEmpty) {
        next = current.apply(
          fromJson(JsonUtils.apply(
            current.value,
            patches,
          )),
          error: next.error,
          isRemote: next.isRemote,
        );
      } else {
        // Vale not changed, use current
        next = current.apply(
          next.value,
          error: next.error,
          isRemote: next.isRemote,
        );
      }
    }
    return next;
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
      _states.delete(key);
      // Can not logically exist anymore, remove it!
      _backlog.remove(key);
      _pushQueue.remove(key.toString());
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
      return schedulePush(
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
  Future<T> onCreate(StorageState<T> state);

  /// Should update state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onUpdate(StorageState<T> state);

  /// Should delete state in [service]
  ///
  /// [SocketException] will push the state to [backlog]
  /// Any other [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<T> onDelete(StorageState<T> state);

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

  /// Reads [states] from storage
  @visibleForOverriding
  Future<Iterable<StorageState<T>>> prepare({
    String postfix,
    bool force = false,
    bool compact = false,
  }) async {
    if (force || _states == null) {
      // Create if not exists
      _pushQueue ??= StreamRequestQueue<T>(
        onError: _shouldStop,
      );
      _loadQueue ??= StreamRequestQueue<Iterable<T>>(
        onError: _shouldStop,
      );

      // Cancel queues
      _pushQueue.cancel();
      _loadQueue.cancel();

      if (compact) {
        await _states?.compact();
      }
      _states = await Hive.openBox(
        toBoxName(
          postfix: postfix,
          runtimeType: runtimeType,
        ),
        encryptionKey: await Storage.hiveKey<T>(),
      );
      // Add local states to backlog
      _backlog
        ..clear()
        ..addAll(
          _states.values.where((state) => state.isCreated).map((state) => toKey(state)),
        );
      _pop();
    }
    // Get mapped states
    return states.values;
  }

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
    _inTransaction = false;
    states.forEach((key, state) {
      if (state.isLocal) {
        _stash(state);
      }
    });
    return _pop();
  }

  /// Queue of [StorageState] processed in FIFO manner.
  ///
  /// This queue ensures that each [StorageState] is
  /// processed in order waiting for it to complete of
  /// fail. This prevents concurrent writes which will
  /// result in an unexpected behaviour due to race
  /// conditions.
  StreamRequestQueue<T> _pushQueue;

  /// Schedule push state to [service]
  ///
  /// This method will return before any
  /// result is received from the [service].
  ///
  /// Errors from [service] are handled
  /// automatically by appropriate actions.
  @protected
  T schedulePush(
    K key, {
    Completer<T> onResult,
  }) {
    final state = getState(key);
    if (state?.isLocal == true) {
      if (_shouldSchedulePush()) {
        // Replace current if not executed yet
        _pushQueue.add(StreamRequest<T>(
          fail: false,
          onResult: onResult,
          fallback: () => Future.value(state.value),
          execute: () => _isReady() ? _executePush(key) : state.value,
        ));
        return state?.value;
      }
      return _stash(state);
    }
    return state?.value;
  }

  Future<StreamResult<T>> _executePush(K key) async {
    try {
      if (_isReady()) {
        final exists = await _waitForDeps(key);
        if (exists && containsKey(key)) {
          final result = await _push(
            getState(key),
          );
          if (_isReady()) {
            put(_patch(
              result,
            ));
          }
          return StreamResult(
            // If patch deleted state, use result before patch
            value: containsKey(key) ? get(key) : result.value,
          );
        }
      }
      return StreamResult.none<T>();
    } catch (error) {
      final state = getState(key);
      if (state != null) {
        put(state.failed(error));
      }
      rethrow;
    }
  }

  bool _isReady() => _states?.isOpen == true && _disposed == false;

  /// Check if dependencies exists remotely
  /// and [waitFor] given time. If dependencies
  /// are still not pushed to remote, give up.
  ///
  /// The method returns [true] if dependencies
  /// exists, [false] otherwise.
  Future<bool> _waitForDeps(
    K key, {
    Duration waitFor = const Duration(milliseconds: 10),
  }) async {
    if (shouldWait(key)) {
      await Future.delayed(waitFor);
    }
    return !shouldWait(key);
  }

  bool _shouldSchedulePush() => connectivity.isOnline && !_inTransaction;

  /// Subscription for handling  offline -> online
  StreamSubscription<ConnectivityStatus> _onlineSubscription;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _retries;
  int _retries = 0;

  T _stash(StorageState<T> state) {
    final key = toKey(state);
    _backlog.add(key);
    _popWhenOnline();
    return state.value;
  }

  void _popWhenOnline() {
    if (_onlineSubscription == null) {
      _onlineSubscription = connectivity.whenOnline.listen(
        (_) => _pop(),
        onError: onError,
        cancelOnError: false,
      );
    }
  }

  Future<List<K>> _pop() async {
    final scheduled = <K>[];

    if (_shouldSchedulePush()) {
      if (_backlog.isNotEmpty) {
        // Cancel processing
        await _loadQueue.stop();
        await _pushQueue.stop();

        // Keys will be added back
        // if schedule fails
        final keys = _backlog.toList();
        _backlog.clear();

        for (var key in keys) {
          schedulePush(key);
          scheduled.add(key);
        }

        // Always complete pending writes
        // before reads to prevent local
        // out-of-order repository updates
        await _pushQueue.process();
        await _loadQueue.process();
      }

      // Only stop timer and reset
      // exponential backoff counter
      // when all pending work is done
      if (!isPending) {
        _retries = 0;
        _timer?.cancel();
      }
    } else {
      _retryPop();
    }

    return scheduled;
  }

  Timer _timer;

  void _retryPop() {
    if (_shouldSchedulePush()) {
      _timer?.cancel();
      _timer = Timer(
        toNextTimeout(_retries++, const Duration(seconds: 10)),
        () {
          if (_shouldSchedulePush()) {
            _pop();
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
      try {
        switch (state.status) {
          case StorageStatus.created:
            return StorageState.created(
              await onCreate(state),
              isRemote: true,
            );
          case StorageStatus.updated:
            return StorageState.updated(
              await onUpdate(state),
              isRemote: true,
            );
          case StorageStatus.deleted:
            return StorageState.deleted(
              await onDelete(state),
              isRemote: true,
            );
        }
        throw RepositoryException('Unable to process $state');
      } on ServiceException catch (e) {
        if (e.is409) {
          return onResolve(state, e.response);
        } else if (e.is404) {
          return onNotFound(state, e.response);
        }
        rethrow;
      }
    }
    return state;
  }

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
      _states.clear();
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
      _states.keys.where((key) => !retainKeys.contains(key)).forEach((key) {
        final state = getState(key);
        if (remote && state.isRemote) {
          keys.add(key);
          evicted.add(state.value);
        } else if (local && state.isLocal) {
          keys.add(key);
          evicted.add(state.value);
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
    if (_isReady()) {
      await _loadQueue.cancel();
      await _pushQueue.cancel();
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
  Future<void> dispose() async {
    _disposed = true;
    _controller.close();
    _timer?.cancel();
    _onlineSubscription?.cancel();
    _timer = null;
    _onlineSubscription = null;
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

@Immutable()
class _StorageState<T> extends StorageState<T> {
  _StorageState(
    this.onGet,
    StorageState<T> state,
  ) : super(
          value: state.value,
          error: state.error,
          status: state.status,
          isRemote: state.isRemote,
        );

  final T Function(T value) onGet;

  T get value => onGet(super.value);
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

  Future<StorageState<T>> call(
    StorageState<T> state,
    ConflictModel conflict,
  ) =>
      reconcile(state, conflict);

  Future<StorageState<T>> reconcile(
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

  /// Default is last writer wins by forwarding to [repository.onUpdate]
  Future<StorageState<T>> onExists(ConflictModel conflict, StorageState<T> state) async {
    return StorageState.updated(
      await repository.onUpdate(state),
      isRemote: true,
    );
  }

  /// Default is to replace local value with remote value
  Future<StorageState<T>> onMerge(ConflictModel conflict, StorageState<T> state) {
    return Future.value(repository.replace(
      repository.fromJson(
        JsonUtils.apply(
          repository.fromJson(conflict.base),
          conflict.yours,
        ),
      ),
      isRemote: true,
    ));
  }

  /// Delete conflicts are not
  /// handled as conflicts, returns
  /// current state value
  Future<StorageState<T>> onDeleted(ConflictModel conflict, StorageState<T> state) => Future.value(state);
}

class RepositoryException implements Exception {
  final String message;
  final StorageState state;
  final StackTrace stackTrace;
  RepositoryException(this.message, {this.state, this.stackTrace});
  @override
  String toString() {
    return '$runtimeType: {message: $message, state: $state, stackTrace: $stackTrace}';
  }
}

class RepositoryServiceException implements Exception {
  final String message;
  final StorageState state;
  final StackTrace stackTrace;
  final ServiceResponse response;
  RepositoryServiceException(this.message, this.response, {this.state, this.stackTrace});
  @override
  String toString() => '$runtimeType: {'
      'message: $message, '
      'response: $response, '
      'state: $state, '
      'stackTrace: $stackTrace'
      '}';
}

class RepositoryRemoteException extends RepositoryException {
  final String message;
  final StackTrace stackTrace;
  RepositoryRemoteException(this.message, {StorageState state, this.stackTrace})
      : super(
          message,
          state: state,
          stackTrace: stackTrace,
        );
}

class RepositoryTimeoutException extends RepositoryException {
  final String message;
  final StackTrace stackTrace;
  RepositoryTimeoutException(this.message, {StorageState state, this.stackTrace})
      : super(
          message,
          state: state,
          stackTrace: stackTrace,
        );
}

class RepositoryIllegalStateValueException extends RepositoryException {
  final String reason;
  final StorageState state;
  RepositoryIllegalStateValueException([
    this.state,
    this.reason,
  ]) : super('[${state.value?.runtimeType}}] state value is invalid: $reason, '
            'state: ${state.runtimeType}, value: ${state.value}, '
            'status: ${state.status}, remote: ${state.isRemote}');
}

class RepositoryNotReadyException extends RepositoryException {
  RepositoryNotReadyException(this.repo) : super('${repo.runtimeType} is not ready');
  final Repository repo;
}

class RepositoryIsDisposedException extends RepositoryException {
  RepositoryIsDisposedException(this.repo) : super('${repo.runtimeType} is disposed');
  final Repository repo;
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
