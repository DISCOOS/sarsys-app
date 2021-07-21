// @dart=2.11

import 'dart:async';
import 'dart:collection';

import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';

import 'mixins.dart';

abstract class BaseBloc<C extends BlocCommand, S extends BlocState, Error extends S> extends Bloc<C, S> {
  BaseBloc(
    S initialState, {
    @required this.bus,
  }) : super(initialState) {
    assert(bus != null, "bus can not be null");
    _subscriptions.add(stream.listen(
      (state) => bus.publish(this, state),
      onError: (e, stackTrace) => addError(e, stackTrace),
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
  /// forwarded to [BlocObserver.onError].
  ///
  BlocHandlerCallback<T> subscribe<T extends BlocState>(BlocHandlerCallback<T> handler) {
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
  /// forwarded to [BlocObserver.onError].
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

  BlocHandlerCallback<T> _subscribe<T extends BlocState>(BlocHandlerCallback<T> handler) =>
      bus.subscribe<T>((Bloc bloc, T event) {
        if (_dispatchQueue.isEmpty) {
          try {
            handler(bloc, event);
          } catch (error, stackTrace) {
            addError(error, stackTrace);
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

  /// List of queues of [BlocState]s processed in FIFO manner.
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
  final _eventQueue = ListQueue<Pair<Bloc, BlocState>>();

  /// Process [BlocState] in FIFO-manner
  /// until [_eventQueue] is empty. Any error
  /// will stop events processing.
  void _processEventQueue() {
    if (_isOpen) {
      try {
        while (_eventQueue.isNotEmpty && _dispatchQueue.isEmpty) {
          final pair = _eventQueue.removeFirst();
          _toHandlers(pair.right).forEach((handler) {
            handler(pair.left, pair.right);
          });
        }
      } catch (error, stackTrace) {
        addError(error, stackTrace);
      }
    }
  }

  /// Get all handlers for given event
  Iterable<Function> _toHandlers(BlocState event) => _handlers[event.runtimeType] ?? [];

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
    } else {
      command.callback.completeError(
        BlocClosedException(this, state, command: command),
        StackTrace.current,
      );
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
    addError(
      error,
      stackTrace ?? StackTrace.current,
    );
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

  @override
  // ignore: must_call_super
  void onError(Object error, StackTrace stackTrace) {
    // ignore: invalid_use_of_protected_member
    Bloc.observer.onError(this, error, stackTrace);
  }

  bool get isClosed => !isOpen;
  bool get isOpen => _isOpen;
  bool _isOpen = true;

  @override
  @mustCallSuper
  Future<void> close() async {
    _processEventQueue();
    _eventQueue.clear();
    _dispatchQueue.clear();
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
    _isOpen = false;
    return super.close();
  }
}

abstract class StatefulBloc<C extends BlocCommand, E extends BlocState, Error extends E, K, V extends JsonObject,
        S extends StatefulServiceDelegate<V, V>> extends BaseBloc<C, E, Error>
    with ReadyAwareBloc<K, V>, ConnectionAwareBloc<K, V, S> {
  StatefulBloc(E initialState, {@required BlocEventBus bus})
      : super(
          initialState,
          bus: bus,
        );

  void forward<T extends JsonObject>(
    C Function(StorageTransition<T>) builder, {
    bool remote = true,
    bool local = false,
    StatefulRepository repo,
  }) {
    final match = repos.firstWhere(
      (repo) => repo.aggregateType == typeOf<T>(),
      orElse: () => typeOf<T>() == JsonObject ? this.repo : null,
    );
    assert(match != null);
    registerStreamSubscription(match.onChanged
        .where(
          (e) => e.isRemote && remote || e.isLocal && local,
        )
        .listen(
          (t) => _processStateChanged<T>(
            t as StorageTransition<T>,
            builder,
          ),
        ));
  }

  void _processStateChanged<T extends JsonObject>(
    StorageTransition<T> transition,
    C Function(StorageTransition<T>) builder,
  ) async {
    try {
      if (isOpen && !transition.isError) {
        final device = transition.to.value;
        if (device != null) {
          final next = transition.to;
          if (next.isRemote) {
            dispatch(
              builder(transition),
            );
          }
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    try {
      return super.close();
    } finally {
      // Allows for any close order
      await Future.wait(
        repos.where((r) => r.isReady).map((r) => r.close()),
      );
    }
  }
}

typedef BlocHandlerCallback<T extends BlocState> = void Function(BaseBloc bloc, T event);

/// [BlocState] bus implementation
class BlocEventBus {
  BlocEventBus(
    void Function(Bloc, Object, StackTrace) onError,
  ) : _onError = onError;

  StreamController<BlocState> _controller = StreamController.broadcast();

  /// Get events as stream
  Stream<BlocState> get events => _controller.stream;

  /// Forward all errors to this error handler
  final void Function(Bloc, Object, StackTrace) _onError;

  /// Registered event routes from Type to to handlers
  final Map<Type, Set<Function>> _routes = {};

  /// Subscribe to event with given handler
  BlocHandlerCallback<T> subscribe<T extends BlocState>(BlocHandlerCallback<T> handler) {
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
  void unsubscribe<T extends BlocState>(BlocHandlerCallback<T> handler) {
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

  void publish(Bloc bloc, BlocState event) {
    _controller.add(event);
    toHandlers(event).forEach((handler) {
      try {
        handler(bloc, event);
      } catch (error, stackTrace) {
        _onError(
          bloc,
          error,
          stackTrace,
        );
      }
    });
  }

  /// Get all handlers for given event
  Iterable<Function> toHandlers(BlocState event) => _routes[event.runtimeType] ?? [];
}

/// -------------
/// Bloc commands
/// -------------

class BlocCommand<D, R> extends Equatable {
  BlocCommand(
    this.data, [
    props = const [],
    Completer<R> callback,
  ])  : callback = callback ?? Completer(),
        _props = [data, ...props];

  final List<Object> _props;

  @override
  List<Object> get props => _props;

  final D data;
  final Completer<R> callback;
  final StackTrace stackTrace = StackTrace.current;
}

/// --------------------
/// Bloc command mixins
/// -------------------

mixin NotifyBlocStateChangedMixin<S extends BlocState<T>, T> on BlocCommand<S, T> {
  @override
  String toString() => '$runtimeType {state: $data}';

  /// Get [BlocState.data]
  T get state => data.data;

  /// Get [BlocState] type
  Type get stateType => typeOf<S>();

  /// Get [BlocState.data] type
  Type get dataType => typeOf<T>();
}

mixin NotifyRepositoryStateChangedMixin<T> on BlocCommand<StorageTransition<T>, T> {
  Type get type => typeOf<T>();

  T get state => data.to.value;
  T get previous => data.from?.value;

  bool get isCreated => data.isCreated;
  bool get isUpdated => data.isChanged;
  bool get isDeleted => data.isDeleted;

  StorageStatus get status => data?.status;
  StateVersion get version => data?.version;

  bool get isRemote => data.to?.isRemote == true;

  @override
  String toString() => '$runtimeType {previous: $data, next: $data}';
}

/// ------------------------
/// Bloc state change events
/// ------------------------
///

abstract class BlocState<T> extends Equatable {
  BlocState(
    this.data, {
    this.stackTrace,
    props = const [],
  }) : _props = [
          data,
          ...props,
          // Ensures events with no
          // props are published by
          // Bloc
          DateTime.now(),
        ];

  final T data;

  final StackTrace stackTrace;

  /// [DateTime] when state was created or mutated
  DateTime get when => props.last;

  @override
  List<Object> get props => _props;
  final List<Object> _props;
}

abstract class PushableBlocEvent<T> extends BlocState<T> {
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

class AppBlocObserver extends BlocObserver {
  AppBlocObserver() : bus = BlocEventBus(_onError);

  final BlocEventBus bus;

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    _onError(bloc, error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  static void _onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    SarSysApp.reportCheckedError(error, stackTrace);
  }

  @override
  void onEvent(BlocBase bloc, Object command) {
    if (kDebugMode && Defaults.debugPrintCommands) {
      debugPrint(
        '--- Command ---\n'
        'bloc:    ${bloc.runtimeType}\n'
        'command: ${command.runtimeType}\n'
        '******************',
      );
    }
    super.onEvent(bloc, command);
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
    super.onTransition(bloc, transition);
  }

  String _toStateString(Object state) {
    if (state is PushableBlocEvent) {
      return '${state.runtimeType}[isRemote: ${state.isRemote}]';
    }
    return '${state.runtimeType}';
  }
}

/// ---------------------
/// Exceptions
/// ---------------------
class BlocClosedException implements Exception {
  BlocClosedException(this.bloc, this.state, {this.command, this.stackTrace});
  final BaseBloc bloc;
  final BlocState state;
  final BlocCommand command;
  final StackTrace stackTrace;

  @override
  String toString() => '${bloc.runtimeType} is closed {state: $state, command: $command, stackTrace: $stackTrace}';
}
