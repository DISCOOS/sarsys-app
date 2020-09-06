import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
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
  Future<List<K>> commit() async {
    _inTransaction = false;
    states.forEach((key, state) {
      if (state.isLocal) {
        _offline(state);
      }
    });
    return _shouldSchedule() ? _online(connectivity.status) : <K>[];
  }

  /// Get value from [key]
  T get(K key) => getState(key)?.value;

  /// Get state from [key]
  StorageState<T> getState(K key) => isReady && _isNotNull(key) ? _states?.get(key) : null;
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
  bool shouldWait(StorageState<T> state) {
    if (state.isLocal) {
      final refs = toRefs(state.value);
      return refs.any(_isRefLocal);
    }
    return false;
  }

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

  /// Queue of [scheduleLoad] processed in FIFO manner.
  ///
  /// This queue ensures that each [load] is
  /// processed in order waiting for it to complete or
  /// fail.
  final _loadQueue = ListQueue<_LoadRequest>();

  /// Get local values and schedule a deferred load request
  @protected
  Iterable<T> scheduleLoad(
    AsyncValueGetter<ServiceResponse<Iterable<T>>> request, {
    bool fail = false,
    int maxAttempts = 3,
    bool shouldEvict = true,
    Completer<Iterable<T>> onResult,
  }) {
    if (_shouldProcessLoadQueue()) {
      // Process LATER but BEFORE any asynchronous
      // events like Future, Timer or DOM Event
      scheduleMicrotask(_processLoadQueue);
    }
    // Replace current
    _loadQueue.clear();
    _loadQueue.add(_LoadRequest<T>(
      fail: fail,
      attempts: 0,
      request: request,
      onResult: onResult,
      shouldEvict: shouldEvict,
      maxAttempts: maxAttempts,
    ));
    return values;
  }

  bool _isProcessingLoad = false;
  bool _shouldProcessLoadQueue() => _loadQueue.isEmpty || _isProcessingLoad != true && _loadQueue.isNotEmpty;

  /// Process [_LoadRequest]s in
  /// FIFO-manner until
  /// [_loadQueue] is empty.
  Future _processLoadQueue() async {
    try {
      _isProcessingLoad = true;
      while (_loadQueue.isNotEmpty) {
        final next = _loadQueue.first;
        // Stop processing when offline
        if (!await _processLoad(next)) {
          break;
        }
        _loadQueue.removeFirst();
      }
    } finally {
      _isProcessingLoad = false;
    }
  }

  // Can NEVER throw!
  // Catch all exceptions and errors
  // and handle them inside this
  // method. If it throws, the load
  // processing loop will exit before
  // queue is empty and never resume
  Future<bool> _processLoad(_LoadRequest command) async {
    var isComplete = false;
    if (command.attempts >= command.maxAttempts) {
      if (command.fail) {
        _onLoadError(
          'Deferred load of ${command.request} failed after ${command.maxAttempts} attempts',
          StackTrace.current,
          command.onResult,
        );
      } else {
        command.onResult?.complete(values);
      }
      // Giving up
      isComplete = true;
    } else if (connectivity.isOnline) {
      isComplete = await _executeLoad(
        command,
      );
    } else {
      // Try again later
      _listenForOnline();
    }
    return isComplete;
  }

  // Can NEVER throw!
  // Catch all exceptions and errors
  // and handle them inside this
  // method. If it throws, the load
  // processing loop will exit before
  // queue is empty and never resume
  Future<bool> _executeLoad(_LoadRequest<T> command) async {
    var isComplete = true;
    try {
      var response = await command.request();
      if (isReady && (response.is200 || response.is206)) {
        _onLoadDone(command, response);
      } else if (response.isErrorCode) {
        _onLoadError(
          response,
          response.stackTrace,
          command.onResult,
        );
      } else {
        // When not ready or
        // 300 http status code
        command.onResult?.complete(values);
      }
      return true;
    } on SocketException {
      // Assume offline
      _listenForOnline();
      isComplete = false;
    } catch (error, stackTrace) {
      _onLoadError(
        error,
        stackTrace,
        command.onResult,
      );
    }
    return isComplete;
  }

  void _onLoadDone(
    _LoadRequest<T> command,
    ServiceResponse<Iterable<T>> response,
  ) {
    final states = response.body.map((value) {
      return StorageState.updated(
        value,
        isRemote: true,
      );
    });
    if (command.shouldEvict) {
      evict(
        retainKeys: states.map(toKey),
      );
    }
    states.forEach(
      (state) => put(_patch(state)),
    );
    command.onResult?.complete(response.body);
  }

  void _onLoadError(
    error,
    StackTrace stackTrace,
    Completer<Iterable<T>> onResult,
  ) {
    onError(
      error,
      stackTrace,
    );
    onResult?.completeError(
      error,
      stackTrace,
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

  StorageState _toState(value, bool isRemote) {
    final state = StorageState<T>.created(
      value,
      isRemote: isRemote,
    );
    final key = toKey(state);
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
    assert(key != null, "key in $next not found");
    final current = _states.get(key);
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

  /// Apply [value] an push to backend
  Future<T> apply(T value) async {
    checkState();
    StorageState next = _toState(
      value,
      false,
    );
    return push(_patch(
      next,
    ));
  }

  /// Delete current value
  Future<T> delete(K key) async {
    checkState();
    return push(
      StorageState.deleted(this[key]),
    );
  }

  /// Apply [state] and push to backend
  @visibleForOverriding
  FutureOr<T> push(StorageState<T> state) {
    checkState();
    final next = validate(state);
    final hasValueChanged = !isValueEqual(next);
    final hasStatusChanged = !isStatusEqual(next);
    final exists = put(next);
    if (exists && (next.isLocal || hasValueChanged || hasStatusChanged)) {
      return schedulePush(next);
    }
    return next.value;
  }

  /// Should reset to remote states in backend
  ///
  /// Any [Exception] will be forwarded to [onError]
  @visibleForOverriding
  Future<Iterable<T>> onReset({Iterable<T> previous});

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
    }
    return _states.values;
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
  @protected
  T schedulePush(StorageState<T> next) {
    if (next.isLocal) {
      if (_shouldSchedule()) {
        if (_shouldProcessPushQueue()) {
          // Process LATER but BEFORE any asynchronous
          // events like Future, Timer or DOM Event
          scheduleMicrotask(_processPushQueue);
        }
        _pushQueue.add(next);
        return next.value;
      }
      return _offline(next);
    }
    return next.value;
  }

  bool _shouldProcessPushQueue() => _pushQueue.isEmpty;

  /// Process [StorageState] in FIFO-manner
  /// until [_pushQueue] is empty.
  Future _processPushQueue() async {
    while (_pushQueue.isNotEmpty) {
      final next = _pushQueue.first;
      try {
        final exists = await _waitForDeps(next);
        if (exists) {
          await _processPush(next);
          _pushQueue.removeFirst();
        }
      } catch (error, stackTrace) {
        // Give up!
        _pushQueue.removeFirst();
        put(next.failed(error));
        onError(error, stackTrace);
      }
    }
  }

  // Can NEVER throw!
  // Catch all exceptions and errors
  // and handle them inside this
  // method. If it throws, the push
  // processing loop will exit before
  // queue is empty and never resume
  Future _processPush(StorageState next) async {
    try {
      if (_isReady()) {
        final result = await _push(
          next,
        );
        if (_isReady()) {
          put(
            _patch(result),
          );
        }
      }
    } on SocketException {
      // Timeout - try again later
      _offline(next);
    } catch (error, stackTrace) {
      put(next.failed(error));
      onError(error, stackTrace);
    }
  }

  bool _isReady() => _states?.isOpen == true;

  /// Check if dependencies exists remotely
  /// and [waitFor] given time. If dependencies
  /// are still not pushed to remote, give up.
  ///
  /// The method returns [true] if dependencies
  /// exists, [false] otherwise.
  Future<bool> _waitForDeps(
    StorageState next, {
    Duration waitFor = const Duration(milliseconds: 10),
  }) async {
    if (shouldWait(next)) {
      await Future.delayed(waitFor);
    }
    return !shouldWait(next);
  }

  bool _shouldSchedule() => connectivity.isOnline && !_inTransaction;

  /// Subscription for handling  offline -> online
  StreamSubscription<ConnectivityStatus> _onlineSubscription;

  T _offline(StorageState<T> state) {
    final key = toKey(state);
    _backlog.add(key);
    _listenForOnline();
    return state.value;
  }

  void _listenForOnline() {
    if (_onlineSubscription == null) {
      _onlineSubscription = connectivity.whenOnline.listen(
        _online,
        onError: onError,
        cancelOnError: false,
      );
    }
  }

  Timer _timer;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _retries;
  int _retries = 0;

  Future<List<K>> _online(ConnectivityStatus status) async {
    final pushed = <K>[];

    _onlineSubscription?.cancel();

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
        // Assume offline
        _retryOnline(status);
        return pushed;
      } catch (error, stackTrace) {
        _backlog.remove(key);
        put(state.failed(error));
        onError(error, stackTrace);
      }
    }

    // Always complete pending writes
    // before reads to prevent local
    // out-of-order repository updates
    await _processLoadQueue();

    // Only stop timer and reset
    // exponential backoff counter
    // when all pending work is done
    if (!isPending) {
      _retries = 0;
      _timer?.cancel();
    }

    return pushed;
  }

  /// Check if load or push is pending
  bool get isPending => _loadQueue.isEmpty && _backlog.isEmpty;

  void _retryOnline(ConnectivityStatus status) {
    if (_shouldSchedule()) {
      _timer?.cancel();
      _timer = Timer(
        toNextTimeout(_retries++, const Duration(seconds: 10)),
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
    if (_isReady()) {
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
    _onlineSubscription?.cancel();
    _timer = null;
    _onlineSubscription = null;
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
    if (_isReady()) {
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

@Immutable()
class _LoadRequest<T> {
  const _LoadRequest({
    @required this.fail,
    @required this.request,
    @required this.attempts,
    @required this.onResult,
    @required this.maxAttempts,
    @required this.shouldEvict,
  });
  final bool fail;
  final int attempts;
  final int maxAttempts;
  final bool shouldEvict;
  final Completer<Iterable<T>> onResult;
  final Future<ServiceResponse<Iterable<T>>> Function() request;

  _LoadRequest<T> retry() => _LoadRequest<T>(
        fail: fail,
        request: request,
        onResult: onResult,
        attempts: attempts + 1,
        shouldEvict: shouldEvict,
        maxAttempts: maxAttempts,
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
    await repository.onUpdate(state);
    return state;
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
