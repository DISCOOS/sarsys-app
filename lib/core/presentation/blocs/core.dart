import 'dart:async';
import 'dart:collection';

import 'package:SarSys/core/defaults.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/utils/data.dart';

abstract class BaseBloc<C extends BlocCommand, S extends BlocEvent, Error extends S> extends Bloc<C, S> {
  BaseBloc({@required this.bus}) : super() {
    assert(bus != null, "bus can not be null");
    _subscriptions.add(listen(
      (state) => bus.publish(this, state),
      onError: (e, stackTrace) => BlocSupervisor.delegate.onError(this, e, stackTrace),
    ));
  }

  /// Get [BlocEventBus]
  final BlocEventBus bus;

  /// Subscriptions released on [close]
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
  final List<StreamSubscription> _subscriptions = [];
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );

  final Map<Type, Set<Function>> _handlers = {};

  /// Subscribe to event with given handler.
  ///
  /// Decisions made in event handlers
  /// must be based on stable states to prevent
  /// unexpected behaviour due to race
  /// conditions with pending commands.
  ///
  /// This method ensures that all commands
  /// are processed before any events are
  /// processed using an internal queue.
  ///
  /// Unhandled exceptions in handles are
  /// forwarded to [BlocDelegate.onError].
  ///
  BlocHandlerCallback<T> subscribe<T extends BlocEvent>(BlocHandlerCallback<T> handler) {
    _handlers.update(
      typeOf<T>(),
      (handlers) => handlers
        ..add(
          _subscribe<T>(handler),
        ),
      ifAbsent: () => {
        _subscribe<T>(handler),
      },
    );
    return handler;
  }

  /// Subscribe to events of given [types] with given [handler]
  ///
  /// Decisions made in event handlers
  /// must be based on stable states to prevent
  /// unexpected behaviour due to race
  /// conditions with pending commands.
  ///
  /// This method ensures that all commands
  /// are processed before any events are
  /// processed using an internal queue.
  ///
  /// Unhandled exceptions in handles are
  /// forwarded to [BlocDelegate.onError].
  ///
  void subscribeAll(BlocHandlerCallback handler, List<Type> types) {
    types.forEach((type) {
      _handlers.update(
        type,
        (handlers) => handlers
          ..add(
            _subscribe(handler),
          ),
        ifAbsent: () => {
          _subscribe(handler),
        },
      );
    });
  }

  BlocHandlerCallback<T> _subscribe<T extends BlocEvent>(BlocHandlerCallback<T> handler) =>
      bus.subscribe<T>((Bloc bloc, T event) {
        if (_dispatchQueue.isEmpty) {
          try {
            handler(bloc, event);
          } catch (error, stackTrace) {
            BlocSupervisor.delegate.onError(
              this,
              error,
              stackTrace,
            );
          }
        } else {
          // Multiple handlers can
          // subscribe to same event
          // type. Don't add duplicates.
          final pair = Pair.of(bloc, event);
          if (!_eventQueue.contains(pair)) {
            _eventQueue.add(pair);
          }
        }
      });

  /// List of queues of [BlocEvent]s processed in FIFO manner.
  ///
  /// Decisions made in event handlers
  /// must be based on stable states to prevent
  /// unexpected behaviour due to race
  /// conditions with pending commands.
  ///
  /// This queue ensures that all commands
  /// are processed before any events are
  /// processed.
  ///
  final _eventQueue = ListQueue<Pair<Bloc, BlocEvent>>();

  /// Process [BlocEvent] in FIFO-manner
  /// until [_eventQueue] is empty. Any error
  /// will stop events processing.
  void _processEventQueue() {
    try {
      while (_eventQueue.isNotEmpty) {
        final pair = _eventQueue.first;
        _toHandlers(pair.right).forEach((handler) {
          handler(pair.left, pair.right);
        });
        _eventQueue.removeFirst();
      }
    } catch (error, stackTrace) {
      BlocSupervisor.delegate.onError(
        this,
        error,
        stackTrace,
      );
    }
    if (!_isOpen) {
      _eventQueue.clear();
      _dispatchQueue.clear();
    }
  }

  /// Get all handlers for given event
  Iterable<Function> _toHandlers(BlocEvent event) => _handlers[event.runtimeType] ?? [];

  /// Queue of [BlocCommand]s processed in FIFO manner.
  ///
  /// This queue ensures that all commands are processed
  /// in order waiting for it to complete of fail before
  /// any events are forwarded to handlers. This prevents
  /// concurrent writes which will result in an unexpected
  /// behaviour due to race conditions.
  ///
  final _dispatchQueue = ListQueue<C>();

  @override
  void add(C command) {
    _dispatchQueue.add(command);
    super.add(command);
  }

  /// Dispatch command and return future of value [T]
  Future<T> dispatch<T>(C command) {
    if (isOpen) {
      add(command);
    }
    return command.callback.future;
  }

  /// Dispatch commands in
  /// sequence and return
  /// future list of type [T]
  Future<List<T>> dispatchAll<T>(List<C> commands) async {
    final results = <T>[];
    for (var command in commands) {
      results.add(
        await dispatch(command),
      );
    }
    return results;
  }

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
      _pop(command);
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

  void _pop(C command) {
    if (_isOpen) {
      _dispatchQueue.remove(command);
    } else {
      _dispatchQueue.clear();
    }
    if (_dispatchQueue.isEmpty) {
      _processEventQueue();
    }
  }

  void onComplete<T>(
    Iterable<Future<T>> list, {
    @required C Function(S state) toCommand,
    @required S Function(Iterable<T> results) toState,
    @required S Function(Object error, StackTrace stackTrace) toError,
  }) async {
    try {
      final results = await Future.wait<T>(list);
      if (isOpen) {
        dispatch(toCommand(toState(
          results,
        )));
      }
    } catch (e, stackTrace) {
      if (isOpen) {
        final state = toError(e, stackTrace);
        if (state != null) {
          dispatch(toCommand(state));
        }
      }
    }
  }

  /// Complete request and
  /// return given state
  ///
  @protected
  S toOK(C event, S state, {Object result}) {
    if (result != null) {
      event.callback.complete(result);
    } else {
      event.callback.complete();
    }
    return state;
  }

  /// Complete with error and
  /// return response as error
  ///
  @protected
  S toError(
    C command,
    Object error, {
    StackTrace stackTrace,
  }) {
    final object = error is Error
        ? error
        : createError(
            error,
            stackTrace: stackTrace ?? StackTrace.current,
          );

    if (!command.callback.isCompleted) {
      command.callback.completeError(
        object.data,
        object.stackTrace ?? StackTrace.current,
      );
    }
    _pop(command);
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

  bool get isClosed => !isOpen;
  bool get isOpen => _isOpen;
  bool _isOpen = true;

  @override
  @mustCallSuper
  Future<void> close() async {
    _processEventQueue();
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
    _isOpen = false;
    return super.close();
  }
}

typedef BlocHandlerCallback<T extends BlocEvent> = void Function(BaseBloc bloc, T event);

/// [BlocEvent] bus implementation
class BlocEventBus {
  BlocEventBus({
    BlocDelegate delegate,
  }) : delegate = delegate ?? BlocSupervisor.delegate;

  final BlocDelegate delegate;
  StreamController<BlocEvent> _controller = StreamController.broadcast();

  /// Get events as stream
  Stream<BlocEvent> get events => _controller.stream;

  /// Registered event routes from Type to to handlers
  final Map<Type, Set<Function>> _routes = {};

  /// Subscribe to event with given handler
  BlocHandlerCallback<T> subscribe<T extends BlocEvent>(BlocHandlerCallback<T> handler) {
    _routes.update(
      typeOf<T>(),
      (handlers) => handlers..add(handler),
      ifAbsent: () => {handler},
    );
    return handler;
  }

  /// Subscribe to event of given [types] with given [handler]
  BlocHandlerCallback subscribeAll(BlocHandlerCallback handler, List<Type> types) {
    for (var type in types) {
      _routes.update(
        type,
        (handlers) => handlers..add(handler),
        ifAbsent: () => {handler},
      );
    }
    return handler;
  }

  /// Unsubscribe given event handler
  void unsubscribe<T extends BlocEvent>(BlocHandlerCallback<T> handler) {
    final handlers = _routes[typeOf<T>()] ?? {};
    handlers.remove(handler);
    if (handlers.isEmpty) {
      _routes.remove(typeOf<T>());
    }
  }

  /// Unsubscribe all event handlers
  void unsubscribeAll() {
    _routes.clear();
    _controller.close();
    _controller = StreamController.broadcast();
  }

  void publish(Bloc bloc, BlocEvent event) {
    _controller.add(event);
    toHandlers(event).forEach((handler) {
      try {
        handler(bloc, event);
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
  Iterable<Function> toHandlers(BlocEvent event) => _routes[event.runtimeType] ?? [];
}

class BlocCommand<D, R> extends Equatable {
  BlocCommand(this.data, [props = const []]) : super([data, ...props]);
  final D data;
  final Completer<R> callback = Completer();
  final StackTrace stackTrace = StackTrace.current;
}

abstract class BlocEvent<T> extends Equatable {
  BlocEvent(this.data, {this.stackTrace, props = const []})
      : super([
          data,
          ...props,
          // Ensures events with no
          // props are published by
          // Bloc
          DateTime.now(),
        ]);

  final T data;
  final StackTrace stackTrace;

  DateTime get created => props.last;
}

abstract class PushableBlocEvent<T> extends BlocEvent<T> {
  PushableBlocEvent(
    T data, {
    StackTrace stackTrace,
    props = const [],
    this.isRemote = false,
  }) : super(
          data,
          stackTrace: stackTrace,
          props: [...props, isRemote],
        );

  final bool isRemote;
  bool get isLocal => !isRemote;
}

class AppBlocDelegate implements BlocDelegate {
  AppBlocDelegate(this.bus);
  final BlocEventBus bus;

  @override
  void onError(Bloc bloc, Object error, StackTrace stackTrace) {
    Catcher.reportCheckedError(error, stackTrace);
  }

  @override
  void onEvent(Bloc bloc, Object command) {
    if (kDebugMode && Defaults.debugPrintCommands) {
      debugPrint(
        '--- Command ---\n'
        'bloc:    ${bloc.runtimeType}\n'
        'command: ${command.runtimeType}\n'
        '******************',
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    if (kDebugMode && Defaults.debugPrintTransitions) {
      debugPrint(
        '--- Transition ---\n'
        'bloc:    ${bloc.runtimeType}\n'
        'command: ${transition.event.runtimeType}\n'
        'current: ${_toStateString(transition.currentState)}\n'
        'next:    ${_toStateString(transition.nextState)}\n'
        '******************',
      );
    }
  }

  String _toStateString(Object state) {
    if (state is PushableBlocEvent) {
      return '${state.runtimeType}[isRemote: ${state.isRemote}]';
    }
    return '${state.runtimeType}';
  }
}
