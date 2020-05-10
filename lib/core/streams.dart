import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Wait for given rule result from stream of results
FutureOr<T> waitThoughtState<S, T>(
  Bloc bloc, {
  @required T Function(S state) map,
  bool fail = false,
  Duration timeout = const Duration(
    milliseconds: 100,
  ),
  bool Function(S state) test,
  FutureOr<T> Function(T value) act,
}) async {
  try {
    await bloc
        .firstWhere(
          (state) => state is S && (test == null || test(state)),
        )
        .timeout(timeout);
  } on Exception {
    if (fail) {
      throw TimeoutException("Failed wait for $T", timeout);
    }
  }
  final value = map(bloc.state);
  if (act == null) {
    return value;
  }
  return await act(value);
}

/// Wait for given rule result from stream of results
Future<Type> awaitThoughtStates(
  Bloc bloc, {
  @required List<Type> expected,
  bool fail = false,
  Duration timeout = const Duration(
    milliseconds: 100,
  ),
}) async {
  try {
    await bloc
        // Match expected events
        .where((event) => expected.contains(event.runtimeType))
        // Match against expected number
        .take(expected.length)
        // Complete when last event is received
        .last
        // Fail on time
        .timeout(timeout);
  } on Exception {
    if (fail) {
      throw TimeoutException("Failed wait for $expected", timeout);
    }
  }
  return bloc.state;
}
