import 'package:SarSys/services/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class UseCase<E, T, P> {
  UseCase({this.concurrent = false});

  /// Flag controlling
  /// if concurrent executions
  /// should be discarded.
  ///
  /// If [true] any number of
  /// concurrent operations are
  /// allowed. Otherwise, only
  /// one operation will be
  /// allowed at any given time.
  final bool concurrent;

  /// Counter of concurrent
  /// operations per type
  static Map<Type, int> _pending = {};
  bool _push() {
    final pending = _pending.update(runtimeType, (pending) => ++pending, ifAbsent: () => 1);
    debugPrint('UseCase:push: $_pending');
    return pending == 1;
  }

  void _pop() {
    final pending = _pending.update(runtimeType, (pending) => --pending, ifAbsent: () => 0);
    if (pending <= 0) {
      _pending.remove(runtimeType);
    }
    debugPrint('UseCase:pop: $_pending');
  }

  /// Execute use case checked.
  /// Returns [null] if operation fails.
  @protected
  Future<Either<E, T>> call(P params) {
    try {
      if (_push() || concurrent) {
        final future = execute(params);
        future.whenComplete(_pop);
        future.catchError(Catcher.reportCheckedError);
        return future;
      }
    } catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
    }
    _pop();
    return null;
  }

  Future<Either<E, T>> execute(P params);
}

class NoParams extends Equatable {}

class BlocParams<B extends Bloc, T> extends Equatable {
  BlocParams(this.data, {B bloc})
      : this.bloc = bloc ?? BlocProvider.of<B>(NavigationService().context),
        super([data]);

  final B bloc;
  final T data;
  OverlayState get overlay => navigation.overlay;
  BuildContext get context => navigation.context;

  /// Check if [context] and [overlay] is available
  bool get navigationAvailable => _navigation.context != null;

  NavigationService get navigation {
    if (!navigationAvailable) {
      throw StateError("Navigation is not available");
    }
    return _navigation;
  }

  final NavigationService _navigation = NavigationService();

  Future<T> pushReplacementNamed<T extends Object>(String path, {Object arguments}) =>
      navigation.pushReplacementNamed<T>(
        path,
        arguments: arguments,
      );
}
