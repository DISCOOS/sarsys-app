import 'dart:async';

import 'package:SarSys/usecase/core.dart';
import 'package:bloc/bloc.dart';

import 'package:SarSys/utils/data_utils.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

abstract class BaseBloc<C extends BlocCommand, S extends BlocEvent, Error extends S> extends Bloc<C, S> {
  BaseBloc({this.bus}) {
    // Publish own events to bus?
    if (bus != null) {
      _subscriptions.add(listen(
        (state) => bus.publish(this, state),
      ));
    }
  }

  /// Get [BlocEventBus]
  final BlocEventBus bus;

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  List<StreamSubscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// [BlocEventHandler]s released on [close]
  List<BlocEventHandler> _handlers = [];
  List<BlocEventHandler> get handlers => List.unmodifiable(_handlers);

  void registerEventHandler<T extends BlocEvent>(BlocEventHandler handler) => _handlers.add(
        bus.subscribe<T>(handler),
      );
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );

  @override
  @protected
  Stream<S> mapEventToState(C command) async* {
    try {
      final errors = <Error>[];

      final stream = execute(command).handleError((error, stackTrace) => errors.add(toError(
            command,
            createError(
              error,
              stackTrace: stackTrace,
            ),
          )));
      yield* stream;
      for (var error in errors) {
        yield error;
      }
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

  /// Dispatch command and return future
  @protected
  Future<S> dispatch<S>(C command) {
    add(command);
    return command.callback.future;
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
    _handlers.forEach((handler) => bus.unsubscribe(handler));
    _handlers.clear();
    return super.close();
  }
}

typedef BlocHandlerBuilder = UseCase Function<T extends BlocEvent>(Bloc bloc, T event);

abstract class BlocEventHandler<T extends BlocEvent> {
  void handle(Bloc bloc, T event);
}

/// [BlocEvent] bus implementation
class BlocEventBus {
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

  void publish(Bloc bloc, BlocEvent event) => toHandlers(event).forEach((handler) => handler.handle(bloc, event));

  /// Get all handlers for given event
  Iterable<BlocEventHandler> toHandlers(BlocEvent event) => _routes[event.runtimeType] ?? [];

  /// Get a single handler for given event.
  ///
  /// If none or more than one is registered, an [InvalidOperation] is thrown.
  BlocEventHandler toHandler(BlocEvent event) {
    final handlers = _routes[event.runtimeType];
    if (handlers == null) {
      throw ArgumentError('No handler found for $event');
    } else if (handlers.length > 1) {
      throw StateError('More than one handler found for $event: $handlers');
    }
    return handlers.first;
  }
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
  BlocEvent(this.data, {this.stackTrace, props = const []}) : super([data, ...props]);
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
