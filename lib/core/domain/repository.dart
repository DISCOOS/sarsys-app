import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:meta/meta.dart';

import 'box_repository.dart';

/// To be used together with [RepositoryProvider]
abstract class Repository<K, V> {
  /// Check if repository is not empty
  bool get isNotEmpty;

  /// Check if repository is empty.
  bool get isEmpty => !isNotEmpty;

  /// Get value from [key]
  V operator [](K key);

  /// Get number of values
  int get length;
}

class RepositoryDelegate {
  /// Called whenever an [error] is thrown in any [BoxRepository]
  /// with the given [repo], [error], and [stackTrace].
  /// The [stacktrace] argument may be `null` if the state stream received an error without a [stackTrace].
  @mustCallSuper
  void onError(Repository repo, Object error, StackTrace stackTrace) {
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

class MergeStrategy<S, T extends JsonObject, U extends Service> {
  MergeStrategy(this.repository);
  final BoxRepository<S, T, U> repository;

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

class RepositoryOfflineException extends RepositoryException {
  final String message;
  final StackTrace stackTrace;
  RepositoryOfflineException(this.message, {StorageState state, this.stackTrace})
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
