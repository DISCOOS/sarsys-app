import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

abstract class BaseBloc<C extends BlocCommand, S extends BlocEvent, Error extends S> extends Bloc<C, S> {
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
}

/// [BlocEvent] bus implementation
class BlocEventBus {
  /// Registered event routes from Type to to handlers
  final Map<Type, List<BlocEventHandler>> _routes = {};

  /// Subscribe to event with given handler
  void subscribe<T extends BlocEvent>(BlocEventHandler<T> handler) => _routes.update(
        typeOf<T>(),
        (handlers) => handlers..add(handler),
        ifAbsent: () => [handler],
      );

  void publish(BlocEvent event) => toHandlers(event).forEach((handler) => handler.handle(event));

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

abstract class BlocEventHandler<T extends BlocEvent> {
  void handle(T event);
}
