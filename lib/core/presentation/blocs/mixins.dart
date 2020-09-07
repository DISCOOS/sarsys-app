import 'dart:async';

import 'package:SarSys/core/domain/repository.dart';

/// ConnectionAwareRepo
mixin ConnectionAwareBloc<S, T> {
  /// Get repositories managed by this [Bloc]
  Iterable<ConnectionAwareRepository> get repos;

  /// Check if bloc is online
  bool get isOnline => repos.first.isOnline;

  /// Check if bloc is offline
  bool get isOffline => repos.first.isOffline;

  /// Check if repository is loading
  bool get isLoading => repos.any((repo) => repo.isLoading);

  /// Get all values
  Iterable<T> get values;

  /// Get [T] from [uuid]
  T operator [](S uuid);

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
    bool fail = false,
    Duration waitFor,
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
      1,
    );
    return _onLoaded.future;
  }

  void _awaitLoaded(
    Completer<Iterable<T>> completer,
    Duration waitFor,
    bool waitForOnline,
    bool fail,
    int retry,
  ) async {
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
        _awaitLoaded(completer, waitFor, waitForOnline, fail, ++retry);
      }
    } else if (!completer.isCompleted) {
      assert(!_shouldWait(waitForOnline), "Should not be loading when online");
      completer.complete(values);
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
