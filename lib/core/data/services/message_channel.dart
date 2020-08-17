import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'package:SarSys/core/extensions.dart';

class MessageChannel extends Service {
  static const int closedByApp = 4000;
  static const int closeAppReopening = 4001;
  static const Map<int, String> closeCodeNames = const {
    WebSocketStatus.normalClosure: 'normalClosure',
    WebSocketStatus.abnormalClosure: 'abnormalClosure',
    WebSocketStatus.goingAway: 'goingAway',
    WebSocketStatus.internalServerError: 'internalServerError',
    WebSocketStatus.invalidFramePayloadData: 'invalidFramePayloadData',
    WebSocketStatus.messageTooBig: 'messageTooBig',
    WebSocketStatus.missingMandatoryExtension: 'missingMandatoryExtension',
    WebSocketStatus.noStatusReceived: 'noStatusReceived',
    WebSocketStatus.policyViolation: 'policyViolation',
    WebSocketStatus.protocolError: 'protocolError',
    WebSocketStatus.reserved1004: 'reserved1004',
    WebSocketStatus.reserved1015: 'reserved1015',
    closedByApp: 'closedByApp',
    closeAppReopening: 'closeAppReopening',
  };

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
    _close(
      reason: _channel.closeReason ?? '$error',
      code: _channel.closeCode ?? WebSocketStatus.abnormalClosure,
    );
  }

  void _onDone() {
    print('MessageChannel::done');
    if (!_isClosed) {
      _close(
        reason: _channel.closeReason ?? 'Done event received',
        code: _channel.closeCode ?? WebSocketStatus.normalClosure,
      );
      if (!_token.isExpired) {
        open(url: _url, token: _token);
      }
    }
  }

  void open({
    @required String url,
    @required AuthToken token,
  }) {
    _close(
      reason: 'App re-opened',
      code: closeAppReopening,
    );
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
    _stats = _stats.update(opened: true);
    debugPrint('Opened message channel');
  }

  bool _isClosed = false;

  void close() {
    _close(
      reason: 'Closed by app',
      code: closedByApp,
    );
  }

  void _close({int code, String reason}) {
    _isClosed = true;
    if (_channel != null) {
      _channel?.sink?.close();
      _channelSubscription?.cancel();
      _channel = null;
      _channelSubscription = null;
      _stats = _stats.update(
        code: code,
        reason: reason,
      );
      debugPrint('Closed message channel');
    }
  }
}

class MessageChannelStatistics {
  MessageChannelStatistics({
    int opened = 0,
    DateTime started,
    int inboundCount = 0,
    Map<int, Map<String, int>> codes = const {},
  })  : _codes = codes,
        _opened = opened,
        _fromDate = started,
        _inboundCount = inboundCount;

  final int _opened;
  final int _inboundCount;
  final DateTime _fromDate;
  final Map<int, Map<String, int>> _codes;

  int get opened => _opened;
  int get inboundCount => _inboundCount;
  Map<int, Map<String, int>> get codes => Map.unmodifiable(_codes);
  double get inboundRate => _inboundCount / min(DateTime.now().difference(_fromDate).inSeconds, 1);

  MessageChannelStatistics update({
    int code,
    int inbound,
    String reason,
    bool opened = false,
  }) {
    assert(
      (code == null && reason == null) || (code != null && reason != null),
      "arguments 'code' and 'reason' must both be null or set",
    );
    final codes = Map<int, Map<String, int>>.from(_codes ?? {});
    if (code != null) {
      codes.update(
        code,
        (reasons) => Map.from(reasons ?? <String, int>{})..update(reason, (count) => count + 1, ifAbsent: () => 1),
        ifAbsent: () => {reason: 1},
      );
    }
    return MessageChannelStatistics(
      started: _fromDate,
      codes: codes,
      opened: opened ? _opened + 1 : _opened,
      inboundCount: inboundCount ?? _inboundCount,
    );
  }

  @override
  String toString() => '$runtimeType{'
      'codes: $_codes,'
      'opened: $opened, '
      'inboundRate: $inboundRate,'
      'inboundCount: $inboundCount, '
      'from: ${_fromDate.toIso8601String()},'
      '}';

  List<Map<String, dynamic>> toCloseReasonAsJson() => codes.entries
      .map((code) => {
            'code': code.key,
            'name': MessageChannel.closeCodeNames[code.key],
            'reasons': code.value.entries
                .map((reason) => {
                      'message': reason.key,
                      'count': reason.value,
                    })
                .toList(),
          })
      .toList();

  String toCloseReasonAsString() {
    JsonEncoder encoder = new JsonEncoder.withIndent('    ');
    return encoder.convert(toCloseReasonAsJson());
  }
}
