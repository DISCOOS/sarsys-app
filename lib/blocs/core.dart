import 'dart:async';
import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/usecase/core.dart';

abstract class BaseBloc<C extends BlocCommand, S extends BlocEvent, Error extends S> extends Bloc<C, S> {
  BaseBloc({this.bus}) {
    // Publish own events to bus?
    if (bus != null) {
      _subscriptions.add(listen(
        (state) => scheduleMicrotask(() => bus.publish(this, state)),
      ));
    }
  }

  /// Get [BlocEventBus]
  final BlocEventBus bus;

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );

  @override
  void add(C command) {
    if (_dispatchQueue.isEmpty) {
      // Process LATER but BEFORE any asynchronous
      // events like Future, Timer or DOM Event
      scheduleMicrotask(_process);
    }
    _dispatchQueue.add(command);
  }

  /// Dispatch command and return future of value [T]
  Future<T> dispatch<T>(C command) {
    add(command);
    return command.callback.future;
  }

  /// Process [BlocCommand] in FIFO-manner until [_dispatchQueue] is empty
  void _process() async {
    while (_dispatchQueue.isNotEmpty) {
      // Dispatch next command and wait for result
      final command = _dispatchQueue.first;
      super.add(command);
      //await command.callback.future;
      // Only remove after execution is completed
      _dispatchQueue.removeFirst();
    }
  }

  /// Queue of [BlocCommand]s processed in FIFO manner.
  ///
  /// This queue ensures that each command is processed
  /// in order waiting for it to complete of fail. This
  /// prevents concurrent writes which will result in
  /// an unexpected behaviour due to race conditions.
  final _dispatchQueue = ListQueue<C>();

  @override
  @protected
  Stream<S> mapEventToState(C command) async* {
    try {
      yield* execute(command).handleError((error, stackTrace) {
        throw toError(
          command,
          createError(
            error,
            stackTrace: stackTrace,
          ),
        );
      });
    } on Exception catch (error, stackTrace) {
      yield toError(
        command,
        createError(
          error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Complete request and
  /// return given state
  ///
  @protected
  S toOK(C event, S state, {Object result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  /// Complete with error and
  /// return response as error
  ///
  @protected
  S toError(C command, Object error) {
    final object = error is Error
        ? error
        : createError(
            error,
            stackTrace: StackTrace.current,
          );
    command.callback.completeError(
      object.data,
      object.stackTrace ?? StackTrace.current,
    );
    return object;
  }

  S toUnsupported(C command) {
    return toError(
      command,
      createError(
        "Unsupported $command",
        stackTrace: StackTrace.current,
      ),
    );
  }

  @visibleForOverriding
  Stream<S> execute(C command);

  @visibleForOverriding
  Error createError(Object error, {StackTrace stackTrace});

  @override
  @mustCallSuper
  Future<void> close() {
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
    return super.close();
  }
}

typedef BlocHandlerBuilder = UseCase Function<T extends BlocEvent>(Bloc bloc, T event);

abstract class BlocEventHandler<T extends BlocEvent> {
  void handle(Bloc bloc, T event);
}

/// [BlocEvent] bus implementation
class BlocEventBus {
  BlocEventBus({
    BlocDelegate delegate,
  }) : delegate = delegate ?? BlocSupervisor.delegate;

  final BlocDelegate delegate;

  /// Registered event routes from Type to to handlers
  final Map<Type, Set<BlocEventHandler>> _routes = {};

  /// Subscribe to event with given handler
  BlocEventHandler<T> subscribe<T extends BlocEvent>(BlocEventHandler<T> handler) {
    _routes.update(
      typeOf<T>(),
      (handlers) => handlers..add(handler),
      ifAbsent: () => {handler},
    );
    return handler;
  }

  /// Unsubscribe given event handler
  void unsubscribe<T extends BlocEvent>(BlocEventHandler<T> handler) {
    final handlers = _routes[typeOf<T>()] ?? {};
    handlers.remove(handler);
    if (handlers.isEmpty) {
      _routes.remove(typeOf<T>());
    }
  }

  /// Unsubscribe all event handlers
  void unsubscribeAll() => _routes.clear();

  void publish(Bloc bloc, BlocEvent event) {
    toHandlers(event).forEach((handler) {
      try {
        handler.handle(bloc, event);
      } on Exception catch (error, stackTrace) {
        delegate.onError(
          bloc,
          error,
          stackTrace,
        );
      }
    });
  }

  /// Get all handlers for given event
  Iterable<BlocEventHandler> toHandlers(BlocEvent event) => _routes[event.runtimeType] ?? [];
}

class BlocCommand<D, R> extends Equatable {
  final D data;
  final Completer<R> callback = Completer();
  final StackTrace stackTrace = StackTrace.current;
  BlocCommand(this.data, [props = const []]) : super([data, ...props]);
}

abstract class BlocEvent<T> extends Equatable {
  final T data;
  final StackTrace stackTrace;

  DateTime get created => props.last;

  BlocEvent(this.data, {this.stackTrace, props = const []})
      : super([
          data,
          ...props,
          // Ensures events with no
          // props are published by
          // Bloc
          DateTime.now(),
        ]);
}

class AppBlocDelegate implements BlocDelegate {
  AppBlocDelegate(this.bus);
  final BlocEventBus bus;

  @override
  void onError(Bloc bloc, Object error, StackTrace stackTrace) {
    Catcher.reportCheckedError(error, stackTrace);
  }

  @override
  void onEvent(Bloc bloc, Object event) {}

  @override
  void onTransition(Bloc bloc, Transition transition) {}
}