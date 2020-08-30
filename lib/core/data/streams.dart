import 'dart:async';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Wait for given rule result from stream of results
FutureOr<T> waitThroughStateWithData<S, T>(
  Bloc bloc, {
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
    await bloc
        .firstWhere(
          (state) => state is S && (test == null || test(state)),
        )
        .timeout(timeout);

    // Map state to value
    value = map(bloc.state);

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

/// Wait for given rule result from stream of results
Future<T> waitThoughtEvents<T>(
  BlocEventBus bus, {
  @required List<Type> expected,
  bool fail = false,
  FutureOr<T> Function() act,
  Duration timeout = const Duration(
    hours: 1,
  ),
}) async {
  try {
    await bus.events
        // Match expected events
        .where((event) => expected.contains(event.runtimeType))
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
