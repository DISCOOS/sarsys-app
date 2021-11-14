

import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:meta/meta.dart';

import 'stateful_repository.dart';

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
  /// Called whenever an [error] is thrown in any [StatefulRepository]
  /// with the given [repo], [error], and [stackTrace].
  /// The [stacktrace] argument may be `null` if the state stream received an error without a [stackTrace].
  @mustCallSuper
  void onError(Repository repo, Object error, StackTrace stackTrace) {
    throw RepositoryException(
      '${repo.runtimeType}: $error',
      repo,
      stackTrace: stackTrace,
    );
  }
}

/// Oversees all [repositories] and delegates responsibilities to the [RepositoryDelegate].
class RepositorySupervisor {
  RepositorySupervisor._();

  static final RepositorySupervisor _instance = RepositorySupervisor._();

  /// [RepositoryDelegate] getter which returns the singleton [RepositorySupervisor] instance's [RepositoryDelegate].
  static RepositoryDelegate get delegate => _instance._delegate;

  /// [RepositoryDelegate] setter which sets the singleton [RepositorySupervisor] instance's [RepositoryDelegate].
  static set delegate(RepositoryDelegate d) {
    _instance._delegate = d ?? RepositoryDelegate();
  }

  /// [RepositoryDelegate] which is notified when events occur in all [bloc]s.
  RepositoryDelegate _delegate = RepositoryDelegate();
}

class RepositoryException implements Exception {
  RepositoryException(
    this.message,
    this.repo, {
    this.state,
    this.stackTrace,
  });
  @override
  String toString() {
    return '$runtimeType: {message: $message, state: $state, stackTrace: $stackTrace}';
  }

  final String message;
  final Repository? repo;
  final StorageState? state;
  final StackTrace? stackTrace;
}

class RepositoryServiceException implements Exception {
  RepositoryServiceException(
    this.message,
    this.response,
    this.repo, {
    this.state,
    this.stackTrace,
  });
  @override
  String toString() => '$runtimeType: {'
      'message: $message, '
      'response: $response, '
      'state: $state, '
      'stackTrace: $stackTrace'
      '}';
  final String message;
  final Repository? repo;
  final StorageState? state;
  final StackTrace? stackTrace;
  final ServiceResponse response;
}

class RepositoryRemoteException extends RepositoryException {
  RepositoryRemoteException(
    String message,
    Repository repo, {
    StorageState? state,
    StackTrace? stackTrace,
  }) : super(
          message,
          repo,
          state: state,
          stackTrace: stackTrace,
        );
}

class RepositoryOfflineException extends RepositoryException {
  RepositoryOfflineException(
    String message,
    Repository repo, {
    StorageState? state,
    StackTrace? stackTrace,
  }) : super(
          message,
          repo,
          state: state,
          stackTrace: stackTrace,
        );
}

class RepositoryDependencyException extends RepositoryException {
  RepositoryDependencyException(
    this.refs,
    Repository? repo, {
    StorageState? state,
    StackTrace? stackTrace,
  }) : super(
          'Dependency timeout: ${refs.map((e) => '${e.type}: ${e.uuid}')}',
          repo,
          state: state,
          stackTrace: stackTrace,
        );
  final List<AggregateRef> refs;
}

class RepositoryTimeoutException extends RepositoryException {
  RepositoryTimeoutException(
    String message,
    Repository? repo, {
    StorageState? state,
    StackTrace? stackTrace,
  }) : super(
          message,
          repo,
          state: state,
          stackTrace: stackTrace,
        );
}

class RepositoryIllegalStateValueException extends RepositoryException {
  RepositoryIllegalStateValueException(
    Repository repo, [
    StorageState? state,
    this.reason,
  ]) : super(
          '[${state!.value?.runtimeType}}] state value is invalid: $reason, '
          'state: ${state.runtimeType}, value: ${state.value}, '
          'status: ${state.status}, remote: ${state.isRemote}',
          repo,
        );
  final String? reason;
}

class RepositoryNotReadyException extends RepositoryException {
  RepositoryNotReadyException(Repository repo)
      : super(
          '${repo.runtimeType} is not ready',
          repo,
        );
}

class RepositoryIsDisposedException extends RepositoryException {
  RepositoryIsDisposedException(Repository repo)
      : super(
          '${repo.runtimeType} is disposed',
          repo,
        );
}

class RepositoryStateExistsException extends RepositoryException {
  RepositoryStateExistsException(
    this.previous,
    this.next,
    Repository repo,
  ) : super('state $previous already exists', repo);
  final StorageState previous;
  final StorageState next;
}

class RepositoryStateNotExistsException extends RepositoryException {
  RepositoryStateNotExistsException(
    Repository repo, [
    this.state,
  ]) : super('state $state does not exists', repo);
  final StorageState? state;
}

class RepositoryIllegalStateException extends RepositoryException {
  RepositoryIllegalStateException(
    this.previous,
    this.next,
    Repository repo,
  ) : super(
          'is in illegal state ${previous.status}, next ${next.status} not allowed',
          repo,
        );
  final StorageState previous;
  final StorageState next;
}
