import 'dart:async';
import 'dart:collection';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:meta/meta.dart';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';

class StreamRequestQueue<T> {
  StreamRequestQueue({this.onError});

  /// List of [StreamRequest.key]s.
  ///
  /// Used to track and dequeue requests.
  final _requests = LinkedHashSet<StreamRequest<T>>();

  /// Error callback.
  ///
  /// Use it to decide if queue should stop
  /// processing [StreamRequest]s until
  /// next time [process] is called based
  /// on [error].
  ///
  final bool Function(Object, StackTrace) onError;

  StreamQueue<StreamRequest<T>> _queue;
  StreamController<StreamRequest<T>> _dispatcher;

  /// Get number of pending [StreamRequest];
  int get length => _requests.length;

  /// Check if queue is empty
  bool get isEmpty => _requests.isEmpty;

  /// Check if queue is not empty
  bool get isNotEmpty => _requests.isNotEmpty;

  /// Flag indicating that [process] should be called
  bool get isIdle => _isIdle || (_isDisposing || _dispatcher == null || _dispatcher.isClosed);
  bool _isIdle = true;

  /// Future returning when queue is
  ///done processing pending requests.
  Future get done => _dispatcher?.done;

  /// Flag indicating that queue is [process]ing requests
  bool get isProcessing => !isIdle;

  /// Check if a [StreamRequest] with given [key] is queued
  bool contains(Object key) => _requests.any((element) => element.key == key);

  /// Returns the index of [StreamRequest] with given [key].
  int indexOf(Object key) => _requests.toList().indexWhere((element) => element.key == key);

  /// Check if [StreamRequest] with given [key] is at head of queue
  bool isHead(Object key) {
    return _requests.isEmpty ? false : _requests.first.key == key;
  }

  /// Get [StreamRequest] currently being processed
  StreamRequest<T> get current => _current;

  /// Check if queue is executing [StreamRequest] with given [key]
  bool isCurrent(Object key) => key != null && _current?.key == key;

  /// Schedule singleton [request] for execution.
  /// This will cancel current requests.
  Future<bool> only(StreamRequest<T> request) async {
    await cancel();
    return add(request);
  }

  /// Schedule [request] for execution
  bool add(StreamRequest<T> request) {
    // Start processing events
    // until isIdle is true.
    // If already processing
    // (not idle), the method
    // will do nothing
    _process();

    final exists = contains(request.key);

    if (!exists) {
      // Schedule request
      _requests.add(request);
      _dispatcher.add(request);
    }

    return !exists;
  }

  /// Remove [StreamRequest] with given [key] from queue.
  bool remove(Object key) {
    if (_current?.key == key) {
      return false;
    }
    final found = _requests.where((element) => element.key == key).toList();
    found.forEach(_requests.remove);
    return found.isNotEmpty;
  }

  /// Remove all pending [StreamRequest]s from queue.
  ///
  /// Returns a list of [StreamRequest]s.
  List<StreamRequest<T>> clear() {
    final removed = _requests.toList();
    _requests.clear();
    return removed;
  }

  /// Process scheduled requests
  Future<void> _process() async {
    StreamResult<T> result;

    if (isIdle) {
      try {
        _prepare();
        while (await _hasNext()) {
          if (isProcessing) {
            final request = await _queue.peek;
            if (isProcessing) {
              if (contains(request.key)) {
                _current = request;
                if (await _shouldExecute(request, result)) {
                  if (isProcessing && contains(request.key)) {
                    result = await _execute(request);
                  }
                }
              } else {
                await _queue.next;
              }
            }
          }
          _current = null;
        }
      } catch (e, stackTrace) {
        _handleError(e, stackTrace);
      } finally {
        await stop();
      }
    }
  }

  /// Prepare queue for requests
  void _prepare() {
    if (isIdle) {
      _dispatcher = StreamController();
      _queue = StreamQueue(
        _dispatcher.stream,
      );
      // Add requests not
      // processed before
      // previous _dispose
      _requests.forEach(
        _dispatcher.add,
      );
      _isIdle = false;
    }
  }

  bool _isDisposing = false;

  Future<void> _dispose() async {
    if (!_isDisposing) {
      _isDisposing = true;
      if (_requests.isNotEmpty && _queue != null) {
        await _queue.cancel(
          immediate: true,
        );
      }
      _queue = null;
      _isIdle = true;
      _current = null;
      _dispatcher = null;
      _isDisposing = false;
    }
    return Future.value();
  }

  StreamRequest<T> _current;

  /// Execute given [request]
  Future<StreamResult<T>> _execute(StreamRequest<T> request) async {
    try {
      final result = await request.execute();
      // Stop processing?
      return await _onComplete(
        request,
        result,
      );
    } catch (error, stackTrace) {
      _handleError(
        error,
        stackTrace,
        onResult: request.onResult,
      );
      return StreamResult(
        value: await _onFallback(request),
      );
    }
  }

  Future<StreamResult<T>> _onComplete(
    StreamRequest<T> request,
    StreamResult<T> result,
  ) async {
    if (_requests.remove(request)) {
      if (_queue != null) {
        await _queue.next;
      }
    }
    if (result.isStop) {
      await stop();
    } else {
      // Notify
      if (request.onResult?.isCompleted == false) {
        if (result.isError) {
          request.onResult.completeError(
            result?.error,
          );
        } else {
          request.onResult.complete(
            result?.value,
          );
        }
      }
    }
    return result;
  }

  /// Should only process next
  /// request if not [isIdle],
  /// if queue contains more
  /// requests, or when next
  /// request is added to it.
  ///
  /// This method will wait
  /// for next request if
  /// [wait] is [true] and
  /// queue is not [isIdle]
  ///
  Future<bool> _hasNext() async {
    if (isProcessing) {
      return await _queue.hasNext;
    }
    return isProcessing;
  }

  Future<bool> _shouldExecute(
    StreamRequest<T> request,
    StreamResult<T> previous,
  ) async {
    if (isIdle) {
      return false;
    }
    final skip = _shouldSkip(request);
    if (skip) {
      if (request.fail) {
        _handleError(
          '${request.runtimeType} failed with to execute with error: ${previous.error}',
          previous.stackTrace ?? StackTrace.current,
          onResult: request.onResult,
        );
      } else if (request.onResult?.isCompleted == false) {
        request.onResult?.complete(
          await _onFallback(request),
        );
      }
    }
    return !skip;
  }

  Future<T> _onFallback(StreamRequest<T> request) => request.fallback == null ? Future<T>.value() : request.fallback();

  /// Check if given request should be skipped
  bool _shouldSkip(StreamRequest request) =>
      // Removed form queue?
      !_requests.contains(request) ||
      // Completed?
      request.onResult?.isCompleted == true;

  /// Error handler.
  /// Will complete [onResult]
  /// with given [error] and
  /// forward to [onError]
  /// for analysis if queue
  /// should return to [isIdle]
  /// state.
  ///
  void _handleError(
    error,
    StackTrace stackTrace, {
    Completer<T> onResult,
  }) {
    if (onResult?.isCompleted == false) {
      onResult.completeError(
        error,
        stackTrace,
      );
    }
    if (onError != null) {
      final shouldStop = onError(
        error,
        stackTrace,
      );
      if (shouldStop) {
        stop();
      }
    }
  }

  /// Start processing requests.
  ///
  bool start() {
    if (isIdle) {
      _process();
    }
    return isProcessing;
  }

  /// Stop processing requests.
  Future<void> stop() async {
    return _dispose();
  }

  /// Cancel all pending requests
  ///and stop processing.
  Future<List<StreamRequest<T>>> cancel() async {
    await _dispose();
    return clear();
  }
}

@Immutable()
class StreamRequest<T> {
  StreamRequest({
    @required this.execute,
    Object key,
    this.fallback,
    this.onResult,
    this.fail = true,
  }) : _key = key;

  final bool fail;
  final Completer<T> onResult;
  final Future<T> Function() fallback;
  final Future<StreamResult<T>> Function() execute;

  Object get key => _key ?? '${super.hashCode}';
  final Object _key;

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StreamRequest && runtimeType == other.runtimeType && key == other.key;
}

@Immutable()
class StreamResult<T> {
  const StreamResult({
    this.value,
    this.error,
    bool stop,
    this.stackTrace,
  }) : _stop = stop ?? false;

  static StreamResult<T> none<T>() => StreamResult<T>();
  static StreamResult<T> stop<T>() => StreamResult<T>(stop: true);

  final T value;
  final bool _stop;
  final Object error;
  final StackTrace stackTrace;

  bool get isStop => _stop;
  bool get isComplete => !isStop;
  bool get isError => error != null;
}

/// Wait for given rule result from stream of results
Future<T> waitThoughtStates<S extends BlocEvent, T>(
  BlocEventBus bus, {
  @required List<Type> expected,
  bool fail = false,
  FutureOr<T> Function() act,
  bool Function(S event) test,
  Duration timeout = const Duration(
    hours: 1,
  ),
}) async {
  try {
    await bus.events
        // Match expected events
        .where((event) => expected.contains(event.runtimeType))
        // Match against test if defined
        .where((state) => test == null || test(state))
        // Match against expected number
        .take(expected.length)
        // Complete when last event is received
        .last
        // Fail on time
        .timeout(timeout);

    // Act on value?
    if (act != null) {
      return await act();
    }
  } on TimeoutException {
    if (fail) {
      throw TimeoutException("Failed wait for $expected", timeout);
    }
  }
  return Future.value();
}

/// Wait for given rule result from stream of results
FutureOr<T> waitThroughStateWithData<S extends BlocEvent, T>(
  BlocEventBus bus, {
  @required T Function(S state) map,
  bool fail = false,
  Duration timeout = const Duration(
    milliseconds: 100,
  ),
  bool Function(S state) test,
  FutureOr<T> Function(T value) act,
}) async {
  T value;
  try {
    final state = await bus.events
        .firstWhere(
          (state) => state is S && (test == null || test(state)),
        )
        .timeout(timeout);

    // Map state to value
    value = map(state);

    // Act on value?
    if (act != null) {
      value = await act(value);
    }
  } on TimeoutException {
    if (fail) {
      throw TimeoutException("Failed to wait for $T", timeout);
    }
  }
  return value;
}
