import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import 'models/AggregateRef.dart';

class StatefulRequestQueue<K, V extends JsonObject, S extends StatefulServiceDelegate<V, V>> {
  StatefulRequestQueue(
    StatefulRepository<K, V, S> repo,
    this.connectivity,
  ) : _repo = repo;

  static const Duration timeLimit = Duration(seconds: 30);

  /// [StatefulRepository] instance
  StatefulRepository<K, V, S> get repo => _repo;
  StatefulRepository<K, V, S> _repo;

  /// [ConnectivityService] instance
  final ConnectivityService connectivity;

  /// Check if repository is online
  bool get isOnline => connectivity.isOnline;

  /// Check if repository is offline
  bool get isOffline => connectivity.isOffline;

  /// Subscription for handling  offline -> online
  StreamSubscription<ConnectivityStatus> _onlineSubscription;

  /// Queue of [load] processed in FIFO manner.
  ///
  /// This queue ensures that each [load] is
  /// processed in order waiting for it to
  /// complete or fail.
  StreamRequestQueue<K, Iterable<V>> _loadQueue;

  /// Check if [load] is scheduled for
  ///request from [service].
  bool get isLoading => _loadQueue?.isNotEmpty == true;

  /// Queue of [StorageState] processed in FIFO manner.
  ///
  /// This queue ensures that each [StorageState] is
  /// processed in order waiting for it to complete of
  /// fail. This prevents concurrent writes which will
  /// result in an unexpected behaviour due to race
  /// conditions.
  StreamRequestQueue<K, V> _pushQueue;

  /// Check if queue is empty
  bool get isEmpty => _loadQueue.isEmpty && _pushQueue.isEmpty;

  /// Check if queue is not empty
  bool get isNotEmpty => !isEmpty;

  /// Get backlog of states pending push to a backend API
  Iterable<K> get backlog => List.unmodifiable(_backlog.keys);
  final _backlog = LinkedHashMap<K, Completer<V>>();

  /// Cancel request processing
  Future cancel() async {
    await _loadQueue?.cancel();
    await _pushQueue?.cancel();
    return Future.value();
  }

  /// Build queue from given [states].
  /// Returns keys of states scheduled for [push].
  Future<Iterable<K>> build(
    Iterable<StorageState<V>> states,
  ) async {
    // Create if not exists
    _pushQueue ??= StreamRequestQueue<K, V>(
      onError: _shouldStop,
    );
    _loadQueue ??= StreamRequestQueue<K, Iterable<V>>(
      onError: _shouldStop,
    );

    // Cancel queues
    _loadQueue.cancel();
    _pushQueue.cancel();

    // Add local states to backlog
    _backlog.clear();
    _backlog.addAll(
      Map.fromEntries(
        states.where((state) => state.isCreated).map((state) => MapEntry(_repo.toKey(state.value), null)),
      ),
    );
    return pop();
  }

  /// Rebuild [backlog] from scheduled keys
  void _rebuild(List<StreamRequest> pending, List<K> scheduled) {
    // Clone backlog
    final next = _backlog.map(
      (key, value) => MapEntry(key, value),
    );

    // Overwrite backlog with pending callbacks
    next.addAll(Map<K, Completer<V>>.fromEntries(
      pending.where((r) => r.onResult != null).map((r) => MapEntry(r.key as K, r.onResult)),
    ));

    _backlog.clear();

    // Rebuild backlog
    for (var entry in next.entries) {
      push(
        entry.key,
        onResult: entry.value,
      );
      scheduled.add(entry.key);
    }
  }

  /// Check if given error should move queue to idle state
  bool _shouldStop(Object error, StackTrace stackTrace) {
    final isServiceError = error is ServiceException;
    final isTemporary = isOffline ||
        error is SocketException ||
        error is ClientException ||
        error is TimeoutException ||
        error is RepositoryOfflineException ||
        error is RepositoryDependencyException ||
        isServiceError && (error as ServiceException).response.isErrorTemporary;

    if (isTemporary) {
      _popWhenOnline();
      return isOffline;
    }
    _repo.onError(
      error,
      stackTrace,
    );
    return isServiceError;
  }

  /// Get local values and schedule a deferred load request
  Iterable<V> load(
    AsyncValueGetter<ServiceResponse<Iterable<StorageState<V>>>> request, {
    V map(V value),
    bool fail = false,
    bool shouldEvict = true,
    Completer<Iterable<V>> onResult,
  }) {
    _assertState();
    // Replace current if not executed yet
    _loadQueue.only(StreamRequest<K, Iterable<V>>(
      fail: fail,
      onResult: onResult,
      execute: () => _executeLoad(
        map,
        request,
        shouldEvict,
      ),
      fallback: () => Future.value(_repo.values),
    ));

    if (isOffline) {
      _popWhenOnline();
    }

    return _repo.values;
  }

  Future<StreamResult<Iterable<V>>> _executeLoad(
    V map(V value),
    AsyncValueGetter<ServiceResponse<Iterable<StorageState<V>>>> request,
    bool shouldEvict,
  ) async {
    _assertState();
    if (isOffline) {
      _popWhenOnline();
      return StreamResult.stop<Iterable<V>>();
    }
    var response = await request();
    if (response != null) {
      if (_repo.isReady && (response.is200 || response.is206)) {
        final states = response.body.map((state) {
          final next = state.remote(
            map == null ? state.value : map(state.value),
            status: StorageStatus.updated,
          );
          if (_repo.containsKey(_repo.toKey(state.value))) {
            return next;
          }
          return state;
        });
        if (shouldEvict) {
          _repo.evict(
            retainKeys: states.map((s) => s.value).map(_repo.toKey),
          );
        }
        states.forEach(
          (state) {
            if (_repo.toKey(state.value) != null) {
              _repo.put(
                _patch(state),
              );
            }
          },
        );
      } else if (response.isErrorCode) {
        return StreamResult<Iterable<V>>(
          error: RepositoryServiceException(
            'Failed to load $request',
            response,
          ),
          stackTrace: response.stackTrace,
        );
      }
    }
    return StreamResult<Iterable<V>>(
      value: _repo.values,
    );
  }

  Completer<Iterable<V>> _onLoaded;

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
    if (_onLoaded?.isCompleted == false) {
      return _onLoaded.future;
    }

    _onLoaded = Completer<Iterable<V>>();
    _awaitLoaded(
      _onLoaded,
      waitFor,
      waitForOnline,
      fail,
    );
    return _onLoaded.future;
  }

  void _awaitLoaded(Completer<Iterable<V>> completer, Duration waitFor, bool waitForOnline, bool fail) async {
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
      completer.complete(_repo.values);
    }
  }

  bool _shouldWait(bool waitForOnline) => isLoading && (_shouldSchedulePush() || isOffline && waitForOnline);

  /// Stash [state] to [backlog] for
  /// processing if local changes exists.
  /// Returns [state] value.
  V stash(
    StorageState<V> state, {
    Completer<V> onResult,
  }) {
    final key = _repo.toKey(state.value);
    if (state.isLocal) {
      _backlog[key] = onResult;
    }
    _popWhenOnline();
    return state.value;
  }

  /// Pop all states in [backlog] to [push]
  Future<List<K>> pop() async {
    final scheduled = <K>[];

    if (_shouldSchedulePush()) {
      // Cancel current
      final pending = await _pushQueue.cancel();

      // Rebuild backlog
      _rebuild(pending, scheduled);

      // Start processing again
      _loadQueue.start();
      _pushQueue.start();

      // Reset retry timer
      _retries = 0;
      _timer?.cancel();
    } else {
      _retryPop();
    }

    return scheduled;
  }

  /// Remove state with given key from [backlog]
  bool remove(K key) {
    final exists = _backlog.containsKey(key) || _pushQueue?.contains(key) == true;
    _backlog.remove(key);
    _pushQueue?.remove(key);
    return exists;
  }

  /// Schedule push state to [service]
  ///
  /// This method will return before any
  /// result is received from the [service].
  ///
  /// Errors from [service] are handled
  /// automatically by appropriate actions.
  V push(
    K key, {
    Completer<V> onResult,
  }) {
    _assertState();
    final state = _repo.getState(key);
    if (state?.isLocal == true) {
      if (_shouldSchedulePush()) {
        // Replace current if not executed yet
        _pushQueue.add(StreamRequest<K, V>(
          key: key,
          fail: false,
          onResult: onResult,
          fallback: () {
            return Future.value(state.value);
          },
          execute: () => _repo.isReady ? _executePush(key) : state.value,
        ));
        return state?.value;
      }
      return stash(
        state,
        onResult: onResult,
      );
    }
    return state?.value;
  }

  Future<StreamResult<V>> _executePush(K key) async {
    try {
      _assertState();
      if (_repo.isReady) {
        if (_repo.containsKey(key)) {
          final exists = await _waitForDeps(key);
          if (exists) {
            final result = await _push(
              _repo.getState(key),
            );
            if (_repo.isReady) {
              _repo.put(_patch(
                result,
              ));
            }
            return StreamResult(
              // If patch deleted state, use result before patch
              value: _repo.containsKey(key) ? _repo.get(key) : result.value,
            );
          } else {
            // Some dependencies where not in remote state
            final state = _repo.getState(key);
            final refs = _repo.toRefs(state.value);
            final error = RepositoryDependencyException(
              refs,
              state: state,
              stackTrace: StackTrace.current,
            );
            _repo.put(
              state.failed(error),
            );
            return StreamResult.failed(
              error,
              stackTrace: StackTrace.current,
            );
          }
        }
      }
      return StreamResult.none();
    } catch (error) {
      final state = _repo.getState(key);
      if (state != null) {
        _repo.put(
          state.failed(error),
        );
      }
      rethrow;
    }
  }

  bool _shouldSchedulePush() => connectivity.isOnline && !_repo.inTransaction;

  /// Push state to remote
  FutureOr<StorageState<V>> _push(StorageState<V> state) async {
    if (state.isLocal) {
      try {
        switch (state.status) {
          case StorageStatus.created:
            return await _repo.onCreate(state);
          // await _repo.onCreate(state)
          // return StorageState.created(
          //   await _repo.onCreate(state),
          //   isRemote: true,
          // );
          case StorageStatus.updated:
            return await _repo.onUpdate(state);
          // return StorageState.updated(
          //   isRemote: true,
          // );
          case StorageStatus.deleted:
            return await _repo.onDelete(state);
          // return StorageState.deleted(
          //   isRemote: true,
          // );
        }
        throw RepositoryException('Unable to process $state');
      } on ServiceException catch (e) {
        if (e.is409) {
          return _repo.onResolve(state, e.response);
        } else if (e.is404) {
          return _repo.onNotFound(state, e.response);
        }
        rethrow;
      }
    }
    return state;
  }

  /// Patch [next] state with existing in repository
  StorageState<V> _patch(StorageState next) {
    final key = _repo.toKey(next.value);
    final current = _repo.getState(key);
    return current == null ? next : current.patch<V>(next, _repo.fromJson);
  }

  /// Check if dependencies exists remotely
  /// and [waitFor] given time. If dependencies
  /// are still not pushed to remote, give up.
  ///
  /// The method returns [true] if dependencies
  /// exists, [false] otherwise.
  Future<bool> _waitForDeps(
    K key, {
    Duration waitFor = timeLimit,
  }) async {
    final tic = DateTime.now();
    while (shouldWait(key) && DateTime.now().difference(tic) < waitFor) {
      await Future.delayed(
        const Duration(milliseconds: 10),
      );
    }
    return !shouldWait(key);
  }

  /// Is called before create, update and delete to
  /// prevent '404 Not Found' returned by service
  /// because dependency was not found in backend.
  bool shouldWait(K key) {
    _assertState();
    final state = _repo.getState(key);
    if (state?.isLocal == true) {
      final refs = _repo.toRefs(state.value);
      return refs.any(_isRefLocal);
    }
    return false;
  }

  /// Check if reference exists local only
  bool _isRefLocal(AggregateRef ref) {
    final state = _repo.dependencies
        .where((dep) => dep.containsKey(ref.uuid))
        .map((dep) => dep.getState(ref.uuid))
        .where((state) => state?.value?.runtimeType == ref.type)
        .firstOrNull;
    if (state != null) {
      return state.isCreated && state.isLocal;
    }
    return false;
  }

  void _popWhenOnline() {
    if (_onlineSubscription == null) {
      _onlineSubscription = connectivity.whenOnline.listen(
        (_) {
          pop();
        },
        cancelOnError: false,
        onError: _repo.onError,
      );
    }
  }

  /// Retry timer
  Timer _timer;

  /// Current number of retries.
  /// Is reset on each offline -> online transition
  int get retries => _retries;
  int _retries = 0;

  void _retryPop() {
    _timer?.cancel();
    _timer = Timer(
      toNextTimeout(_retries++, const Duration(seconds: 10)),
      () {
        if (_shouldSchedulePush()) {
          pop();
        }
      },
    );
  }

  /// Get next timeout with exponential backoff
  static Duration toNextTimeout(int retries, Duration maxBackoffTime, {int exponent = 2}) {
    final wait = min(
      pow(exponent, retries++).toInt() + Random().nextInt(1000),
      maxBackoffTime.inMilliseconds,
    );
    return Duration(milliseconds: wait);
  }

  /// Flag is true after
  /// [dispose] is called.
  bool get isDisposed => _disposed;
  bool _disposed = false;

  /// Asserts that repository is operational.
  /// Should be called before methods is called.
  /// If not ready an [StateError] is thrown
  @protected
  void _assertState() {
    if (_disposed) {
      throw StateError('$runtimeType is disposed');
    }
  }

  /// Dispose repository
  ///
  /// After this point it can
  /// not used again.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _onlineSubscription?.cancel();
    _timer = null;
    _repo = null;
    _onlineSubscription = null;
  }
}
