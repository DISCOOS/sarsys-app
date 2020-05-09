import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Wait for given rule result from stream of results
Future<T> waitThoughtState<S, T>(
  Bloc bloc, {
  bool fail = false,
  Duration timeout = const Duration(
    milliseconds: 100,
  ),
  bool Function(S state) test,
  T Function(S state) map,
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
  return map == null ? bloc.state : map(bloc.state);
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
