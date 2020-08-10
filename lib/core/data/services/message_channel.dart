import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'package:SarSys/core/extensions.dart';

class MessageChannel extends Service {
  AuthToken _token;
  IOWebSocketChannel _channel;
  StreamSubscription _channelSubscription;
  MessageChannelStatistics _stats = MessageChannelStatistics();

  /// Get web-service url
  String get url => _url;
  String _url;

  /// Registered event routes from [Type] to handlers
  final Map<String, Set<Function>> _routes = {};

  /// Check if channel is open
  bool get isOpen => !_isClosed;

  /// Get [MessageChannelStatistics]
  MessageChannelStatistics get stats => _stats;

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
        _stats = _stats.update(inbound: 1);
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
    _stats = _stats.update(connected: true);
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

class MessageChannelStatistics {
  MessageChannelStatistics({
    int connected = 0,
    int inboundCount = 0,
    DateTime started,
  })  : _connected = connected,
        _inboundCount = inboundCount,
        _fromDate = started;

  final int _connected;
  final int _inboundCount;
  final DateTime _fromDate;

  int get connected => _connected;
  int get inboundCount => _inboundCount;
  double get inboundRate => _inboundCount / min(DateTime.now().difference(_fromDate).inSeconds, 1);

  MessageChannelStatistics update({
    int inbound,
    bool connected = false,
  }) =>
      MessageChannelStatistics(
        started: _fromDate,
        inboundCount: inboundCount ?? _inboundCount,
        connected: connected ? _connected + 1 : _connected,
      );

  @override
  String toString() => '$runtimeType{'
      'connected: $connected, '
      'inboundRate: $inboundRate,'
      'inboundCount: $inboundCount, '
      'from: ${_fromDate.toIso8601String()},'
      '}';
}
