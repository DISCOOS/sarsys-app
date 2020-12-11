import 'dart:async';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/domain/repository.dart';

mixin ReadyAwareBloc<S, T> {
  /// Check if bloc is ready
  bool get isReady;

  /// Stream of isReady changes
  Stream<bool> get onReadyChanged;

  /// Wait on [isReady] is [true]
  Future<bool> get onReady => isReady ? Future.value(true) : onReadyChanged.where((state) => state).first;

  /// Wait on [isReady] is [false]
  Future<bool> get onNotReady => !isReady ? Future.value(false) : onReadyChanged.where((state) => !state).first;
}

/// Connection aware [Bloc] mixin
mixin ConnectionAwareBloc<K, V extends JsonObject, S extends StatefulServiceDelegate<V, V>> on ReadyAwareBloc<K, V> {
  /// Default timeout on requests that
  /// should return within finite time
  static const Duration timeLimit = const Duration(seconds: 1);

  /// Check if bloc is online
  bool get isOnline => repo.isOnline;

  /// Check if bloc is offline
  bool get isOffline => repo.isOffline;

  /// Check if repository is loading
  bool get isLoading => repos.whereType<StatefulRepository>().any((repo) => repo.isLoading);

  /// Get [StatefulRepository] instance
  StatefulRepository<K, V, S> get repo;

  /// Get <ll repositories managed by this [Bloc]
  Iterable<StatefulRepository> get repos => [repo];

  /// Get all [V]s
  Iterable<V> get values => repo.values;

  /// Get [V] from [uuid]
  V operator [](K uuid) => repo[uuid];

  /// Get [StatefulServiceDelegate] instance
  S get service => repo.service;

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
    bool fail = false,
    bool waitForOnline = false,
  }) async {
    await onReady;

    if (_onLoaded?.isCompleted == false) {
      return _onLoaded.future;
    }

    _onLoaded = Completer<Iterable<V>>();
    _awaitLoaded(
      _onLoaded,
      waitForOnline,
      fail,
      1,
    );

    return _onLoaded == null ? Future.value(values) : _onLoaded.future;
  }

  void _awaitLoaded(
    Completer<Iterable<V>> completer,
    bool waitForOnline,
    bool fail,
    int retry,
  ) async {
    // Only wait if loading with connectivity
    // online, or wait for online is requested
    if (_shouldWait(waitForOnline)) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      );
    }

    if (_shouldWait(waitForOnline)) {
      if (fail) {
        completer.completeError(
          RepositoryTimeoutException(
            "Waiting on $runtimeType to complete async loads failed",
          ),
          StackTrace.current,
        );
        _onLoaded = null;
      } else {
        _awaitLoaded(
          completer,
          waitForOnline,
          fail,
          ++retry,
        );
      }
    } else if (!completer.isCompleted) {
      assert(!_shouldWait(waitForOnline), "Should not be loading when online");
      completer.complete(values);
      _onLoaded = null;
    }
  }

  bool _shouldWait(bool waitForOnline) => isLoading && (isOnline || isOffline && waitForOnline);
}

/// Initialize data source
mixin InitableBloc<Type> {
  Future<Type> init();
}

/// Load data from data source
mixin LoadableBloc<Type> {
  Future<Type> load();
}

/// Create [data] in data source
mixin CreatableBloc<Type> {
  Future<Type> create(Type create);
}

/// Update [data] in data source
mixin UpdatableBloc<Type> {
  Future<Type> update(Type data);
}

/// Delete [data] from data source
mixin DeletableBloc<Type> {
  Future<Type> delete(String uuid);
}

/// Unload data from source source
mixin UnloadableBloc<Type> {
  Future<Type> unload();
}
