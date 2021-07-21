// @dart=2.11

import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/process/presentation/pages/progress_page.dart';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class UseCase<E, T, P> {
  UseCase({
    this.failure,
    this.isModal = false,
    this.isConcurrent = false,
  });

  /// Value returned on failure
  final E failure;

  /// Flag controlling
  /// if concurrent executions
  /// should be discarded.
  ///
  /// If [true] any number of
  /// concurrent operations are
  /// allowed. Otherwise, only
  /// one operation will be
  /// allowed at any given time.
  final bool isConcurrent;

  /// Flag controlling use case
  /// modality. If [true] an
  /// modal dialog is shown
  /// until use case is completed
  final bool isModal;

  bool _isModalOpen = false;

  /// Counter of concurrent
  /// operations per type
  static Map<Type, int> _pending = {};
  bool _push() {
    final pending = _pending.update(
      runtimeType,
      (pending) => ++pending,
      ifAbsent: () => 1,
    );
    debugPrint('$runtimeType:push: $_pending');
    if (pending == 1 && isModal) {
      _isModalOpen = true;
      showDialog(
        context: NavigationService().overlay.context,
        builder: (context) => ProgressPage(),
      ).then((_) => _isModalOpen = false);
    }
    return pending == 1;
  }

  void _pop() {
    final pending = _pending.update(
      runtimeType,
      (pending) => --pending,
      ifAbsent: () => 0,
    );
    if (pending <= 0) {
      _pending.remove(runtimeType);
      if (isModal && _isModalOpen) {
        NavigationService().overlayPop();
      }
    }
    debugPrint('$runtimeType:pop: $_pending');
  }

  /// Execute use case checked.
  /// Returns [null] if operation fails.
  @protected
  Future<Either<E, T>> call(P params) {
    try {
      if (_push() || isConcurrent) {
        return execute(params);
      }
    } catch (error, stackTrace) {
      SarSysApp.reportCheckedError(error, stackTrace);
    } finally {
      _pop();
    }
    return Future.value(left<E, T>(failure));
  }

  Future<Either<E, T>> execute(P params);
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}

class BlocParams<B extends Bloc, T> extends Equatable {
  BlocParams(this.data, {B bloc}) : this.bloc = bloc ?? BlocProvider.of<B>(NavigationService().context);

  @override
  List<Object> get props => [data];

  final B bloc;
  final T data;
  OverlayState get overlay => navigation.overlay;
  BuildContext get context => navigation.context;
  BlocEventBus get bus => bloc is BaseBloc ? (bloc as BaseBloc).bus : null;

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
