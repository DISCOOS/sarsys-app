import 'dart:async';
import 'dart:convert';

import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'package:SarSys/core/extensions.dart';

class MessageChannel {
  String _url;
  AuthToken _token;
  IOWebSocketChannel _channel;
  StreamSubscription _channelSubscription;

  /// Registered event routes from [Type] to handlers
  final Map<String, Set<Function>> _routes = {};

  /// Subscribe to event with given handler
  ValueChanged<Map<String, dynamic>> subscribe(String type, ValueChanged<Map<String, dynamic>> handler) {
    _routes.update(
      '$type',
      (handlers) => handlers..add(handler),
      ifAbsent: () => {handler},
    );
    return handler;
  }

  /// Subscribe to event with given handler
  ValueChanged<Map<String, dynamic>> subscribeAll(ValueChanged<Map<String, dynamic>> handler, List<String> types) {
    for (var type in types) {
      _routes.update(
        '$type',
        (handlers) => handlers..add(handler),
        ifAbsent: () => {handler},
      );
    }
    return handler;
  }

  /// Unsubscribe given event handler
  void unsubscribe(String type, ValueChanged handler) {
    final handlers = _routes['$type'] ?? {};
    handlers.remove(handler);
    if (handlers.isEmpty) {
      _routes.remove(type);
    }
  }

  /// Unsubscribe all event handlers
  void unsubscribeAll({List<String> types = const []}) {
    if (types.isEmpty) {
      _routes.clear();
    } else {
      _routes.removeWhere((key, _) => types.contains(key));
    }
  }

  void _onData(dynamic event) {
    try {
      final data = json.decode(event);
      if (data is Map) {
        final type = data.elementAt<String>('type');
        _toHandlers(type).forEach((handler) {
          try {
            handler(data);
          } catch (e, stackTrace) {
            Catcher.reportCheckedError(e, stackTrace);
          }
        });
      }
    } catch (e, stackTrace) {
      Catcher.reportCheckedError(
        'Failed to decode message: $event, error: $e',
        stackTrace,
      );
    }
  }

  /// Get all handlers for given type
  Iterable<Function> _toHandlers(String type) => _routes[type] ?? [];

  void _onError(Object error, StackTrace stackTrace) {
    print(error);
    print(stackTrace);
    close();
  }

  void _onDone() {
    print('MessageChannel::done');
    if (!_isClosed) {
      close();
      if (!_token.isExpired) {
        open(url: _url, token: _token);
      }
    }
  }

  void open({
    @required String url,
    @required AuthToken token,
  }) {
    close();
    _url = url;
    _token = token;
    _channel = IOWebSocketChannel.connect(url, headers: {
      'Authorization': 'Bearer ${token.accessToken}',
    });
    _channelSubscription = _channel.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );
    _isClosed = false;
    debugPrint('Opened message channel');
  }

  bool _isClosed = false;

  void close() {
    _isClosed = true;
    if (_channel != null) {
      _channel?.sink?.close();
      _channelSubscription?.cancel();
      _channel = null;
      _channelSubscription = null;
      debugPrint('Closed message channel');
    }
  }
}
