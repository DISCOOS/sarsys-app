

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/core/data/models/subscription_model.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';

import 'package:SarSys/core/extensions.dart';

import 'navigation_service.dart';

class MessageChannel extends Service {
  MessageChannel(UserRepository users) : _users = users;

  static const int closedByApp = 4000;
  static const int closeAppReopening = 4001;
  static const int closeAppIsOffline = 4002;
  static const int closeApiUnreachable = 4003;
  static const Map<int, String> closeCodeNames = const {
    status.normalClosure: 'normalClosure',
    status.abnormalClosure: 'abnormalClosure',
    status.goingAway: 'goingAway',
    status.internalServerError: 'internalServerError',
    status.invalidFramePayloadData: 'invalidFramePayloadData',
    status.messageTooBig: 'messageTooBig',
    status.missingMandatoryExtension: 'missingMandatoryExtension',
    status.noStatusReceived: 'noStatusReceived',
    status.policyViolation: 'policyViolation',
    status.protocolError: 'protocolError',
    1004: 'reserved1004',
    1015: 'reserved1015',
    closedByApp: 'closedByApp',
    closeAppReopening: 'closeAppReopening',
    closeAppIsOffline: 'closeAppIsOffline',
    closeApiUnreachable: 'closeApiUnreachable',
  };

  IOWebSocketChannel? _channel;
  List<StreamSubscription> _subscriptions = [];
  MessageChannelState _stats = MessageChannelState();
  StreamController<MessageChannelState> _statsController = StreamController.broadcast();

  /// Get web-service url
  String? get url => _url;
  String? _url;

  /// Get current app id
  String? get appId => _appId;
  String? _appId;

  SubscriptionModel? get config => _config;
  SubscriptionModel? _config;

  /// Get current [AuthToken]
  AuthToken? get token => _users.token;

  /// Check if [AuthToken] is valid
  bool get isTokenValid => _users.isTokenValid;

  /// Check if [AuthToken] is expired
  bool get isTokenExpired => _users.isTokenExpired;

  /// [UserRepository] for token handling
  final UserRepository _users;

  /// Registered event routes from [Type] to handlers
  final Map<String, Set<Function>> _routes = {};

  /// Check if channel is open
  bool get isOpen => !_isClosed;

  /// Get [MessageChannelState]
  MessageChannelState get state => _stats;

  /// Get stream os [MessageChannelState] changes
  Stream<MessageChannelState> get onChanged => _statsController.stream;

  /// Subscribe to event with given handler
  ValueChanged<Map<String, dynamic>> subscribe(String type, ValueChanged<Map<String, dynamic>> handler) {
    _assertState();
    _routes.update(
      type,
      (handlers) => handlers..add(handler),
      ifAbsent: () => {handler},
    );
    return handler;
  }

  /// Subscribe to event with given handler
  ValueChanged<Map<String, dynamic>> subscribeAll(ValueChanged<Map<String, dynamic>> handler, List<String> types) {
    _assertState();
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
  void unsubscribe(String type, ValueChanged handler) {
    _assertState();
    final handlers = _routes['$type'] ?? {};
    handlers.remove(handler);
    if (handlers.isEmpty) {
      _routes.remove(type);
    }
  }

  /// Unsubscribe all event handlers
  void unsubscribeAll({List<String> types = const []}) {
    _assertState();
    if (types.isEmpty) {
      _routes.clear();
    } else {
      _routes.removeWhere((key, _) => types.contains(key));
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message);
      if (data is Map) {
        final type = data.elementAt<String>('type')!.toLowerCase();
        debugPrint('MessageChannel >> received $data');
        switch (type) {
          case 'changes':
            _onChanges(data);
            break;
          case 'status':
            // TODO: Handle status / ack
            debugPrint('MessageChannel >> Status OK');
            break;
          case 'error':
            // TODO: Handle error / ack
            debugPrint(
              'MessageChannel >> Error: ${data.elementAt('data/code')} ${data.elementAt('data/reason')}',
            );
            break;
          default:
            SarSysApp.reportCheckedError(
              'Unknown message type: $message',
              StackTrace.current,
            );
            break;
        }
      } else {
        SarSysApp.reportCheckedError(
          'Unknown message format: $message',
          StackTrace.current,
        );
      }
      _stats = _stats.update(inbound: 1);
      _statsController.add(_stats);
    } catch (e, stackTrace) {
      SarSysApp.reportCheckedError(
        'Failed to decode message: $message, error: $e',
        stackTrace,
      );
    }
  }

  void _onChanges(Map changes) {
    try {
      for (var state in changes.listAt<Map>('entries', defaultList: <Map>[])!) {
        final type = state.elementAt('event/type');
        final event = state.mapAt<String, dynamic>('event');
        _toHandlers(type).forEach((handler) {
          handler(event);
        });
      }
    } catch (e, stackTrace) {
      SarSysApp.reportCheckedError(e, stackTrace);
    }
  }

  /// Get all handlers for given type
  Iterable<Function> _toHandlers(String? type) => _routes[type!] ?? [];

  void _onError(Object error, StackTrace stackTrace) {
    if (_users.isOffline) {
      _close(
        reason: "App is offline",
        code: MessageChannel.closeAppIsOffline,
      );
    } else if (error is SocketException) {
      _close(
        reason: "APi is unreachable",
        code: MessageChannel.closeApiUnreachable,
      );
    } else {
      debugPrint('MessageChannel >> Error: $error');
      debugPrint('MessageChannel >> Stacktrace: $stackTrace');
      _close(
        reason: _channel!.closeReason ?? '$error',
        code: _channel!.closeCode ?? WebSocketStatus.abnormalClosure,
      );
    }
  }

  void _onDone() async {
    debugPrint('MessageChannel >> Subscription is DONE');
    if (!_isClosed) {
      _close(
        reason: _channel!.closeReason ?? 'Done event received',
        code: _channel!.closeCode ?? WebSocketStatus.goingAway,
      );
    }
  }

  void open({
    required String url,
    required String? appId,
    SubscriptionModel? config,
  }) {
    _assertState();
    _close(
      reason: 'App re-opened',
      code: closeAppReopening,
    );

    _url = url;
    _appId = appId;
    _isClosed = false;
    _config = config ?? _config;

    _channel = IOWebSocketChannel.connect(
      url,
      headers: {
        'x-app-id': '$appId',
        'Authorization': 'Bearer ${token!.accessToken}',
      },
      pingInterval: Duration(seconds: 60),
    );

    _subscribeToMessages();
    _subscribeToConnectivityChanges();

    _stats = _stats.update(opened: true);
    _statsController.add(_stats);

    debugPrint('MessageChannel >> Opened message channel');

    _sendConfig(_config!);
  }

  bool configure(SubscriptionModel config) {
    final changed = config != null && _config != config;
    if (changed) {
      _config = config;
      _sendConfig(config);
    }
    return changed;
  }

  void _sendConfig(SubscriptionModel config) {
    try {
      _channel!.sink.add(
        json.encode({
          'uuid': Uuid().v4(),
          'type': 'Subscribe',
          'data': config.toJson(),
        }),
      );
      debugPrint(
        'MessageChannel >> Sent subscription config $config',
      );
    } catch (e, stackTrace) {
      SarSysApp.reportCheckedError(
        'MessageChannel >> Sending config $config failed with $e',
        stackTrace,
      );
    }
  }

  void _subscribeToMessages() {
    return _subscriptions.add(_channel!.stream.listen(
      _onMessage,
      onDone: _onDone,
      onError: _onError,
    ));
  }

  void _subscribeToConnectivityChanges() {
    return _subscriptions.add(_users.connectivity!.changes.listen(
      _onConnectivityChange,
    ));
  }

  int? _lastCode;
  bool _isClosed = false;
  bool get isClosedByApp => _lastCode == closedByApp;

  void close() {
    _assertState();
    _close(
      reason: 'Closed by app',
      code: closedByApp,
    );
  }

  void _close({int? code, String? reason}) {
    if (_channel != null) {
      _isClosed = true;
      _lastCode = code;
      _channel?.sink.close(status.goingAway);
      _subscriptions.forEach(
        (subscription) => subscription.cancel(),
      );
      _subscriptions.clear();
      _channel = null;
      _stats = _stats.update(
        code: code,
        reason: emptyAsNull(reason!) ?? 'None',
      );
      _statsController.add(_stats);
      debugPrint('MessageChannel >> Closed message channel');
      _check();
    }
  }

  void _assertState() {
    if (_statsController == null) {
      throw StateError('$runtimeType is disposed');
    }
  }

  void dispose() {
    _close(
      code: closedByApp,
      reason: "Disposed",
    );
    _statsController.close();
  }

  void _onConnectivityChange(ConnectivityStatus status) {
    if (status == ConnectivityStatus.offline) {
      if (isOpen) {
        _close(
          reason: "App is offline",
          code: MessageChannel.closeAppIsOffline,
        );
      }
    } else {
      _check();
    }
  }

  void _check() async {
    try {
      if (!isClosedByApp && _users.hasToken && _isClosed) {
        if (_users.isOnline) {
          if (isTokenExpired) {
            await _users.refresh();
          }
          if (isTokenValid) {
            open(
              url: _url!,
              appId: _appId,
              config: _config,
            );
          }
        }
        if (_subscriptions.isEmpty) {
          _subscribeToConnectivityChanges();
        }
      }
    } on UserServiceException {
      _close(
        reason: "Unable to refresh token",
        code: MessageChannel.closedByApp,
      );
      // Prompt user to login
      NavigationService().pushReplacementNamed(
        LoginScreen.ROUTE,
      );
    }
  }
}

class MessageChannelState {
  MessageChannelState({
    int opened = 0,
    DateTime? started,
    int inboundCount = 0,
    Map<int, Map<String?, int>> codes = const {},
  })  : _codes = codes ?? {},
        _opened = opened ?? 0,
        _inboundCount = inboundCount ?? 0,
        _fromDate = started ?? DateTime.now();

  final int _opened;
  final int _inboundCount;
  final DateTime _fromDate;
  final Map<int, Map<String?, int>> _codes;

  int get opened => _opened;

  int get inboundCount => _inboundCount;

  Map<int, Map<String, int>> get codes => Map.unmodifiable(_codes);

  double get inboundRate => _inboundCount / min(DateTime.now().difference(_fromDate).inSeconds, 1);

  MessageChannelState update({
    int? code,
    int? inbound,
    String? reason,
    bool opened = false,
  }) {
    assert(
      (code == null && reason == null) || (code != null && reason != null),
      "arguments 'code' and 'reason' must both be null or set",
    );
    final Map<int, Map<String?, int>> codes = Map<int, Map<String, int>>.from(_codes ?? {});
    if (code != null) {
      codes.update(
        code,
        (reasons) => Map.from(reasons ?? <String, int>{})..update(reason, (count) => count + 1, ifAbsent: () => 1),
        ifAbsent: () => {reason: 1},
      );
    }
    return MessageChannelState(
      codes: codes,
      started: _fromDate,
      opened: opened ? _opened + 1 : _opened,
      inboundCount: _inboundCount + (inbound ?? 0),
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
