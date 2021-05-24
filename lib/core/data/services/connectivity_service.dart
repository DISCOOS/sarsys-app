import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:internet_speed_test/internet_speed_test.dart';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';

class ConnectivityService extends Service {
  factory ConnectivityService() {
    if (_singleton == null || _singleton._disposed) {
      _singleton = ConnectivityService._internal();
    } else {
      _singleton.update();
    }
    return _singleton;
  }

  ConnectivityService._internal() {
    Connectivity().checkConnectivity().then((result) {
      _handleResult(result);
      _speedTimer = Timer.periodic(Duration(minutes: 1), (_) {
        _handleResult(_result);
      });
      _statusTimer = Timer.periodic(Duration(seconds: 3), (_) {
        _handleResult(_result);
      });
    });
    // Throttle down check interval (we are checking our self to calculate delays)
    DataConnectionChecker().checkInterval = const Duration(minutes: 1);
    _subscriptions.add(Connectivity().onConnectivityChanged.listen(_handleResult));
    _subscriptions.add(DataConnectionChecker().onStatusChange.listen(_handleStatusChange));

    // Replace default timeout with local defaults
    DataConnectionChecker().addresses = DataConnectionChecker.DEFAULT_ADDRESSES
        .map(
          (options) => AddressCheckOptions(
            options.address,
            port: options.port,
            timeout: defaultTimeout,
          ),
        )
        .toList();
  }

  static ConnectivityService _singleton;
  static const defaultTimeout = const Duration(seconds: 1);

  final internetSpeedTest = InternetSpeedTest();
  final StreamController<ConnectivityStatus> _controller = StreamController<ConnectivityStatus>.broadcast();

  Timer _speedTimer;
  Timer _statusTimer;
  bool _disposed = false;
  bool _hasConnection = true;
  List<StreamSubscription> _subscriptions = [];
  ConnectivityResult _result = ConnectivityResult.none;

  /// Check if connected to [ConnectivityStatus.wifi]
  bool get isWifi => ConnectivityStatus.wifi == _status;

  /// Check if not [ConnectivityStatus.offline]
  bool get isOnline => ConnectivityStatus.offline != _status;

  /// Check if [ConnectivityStatus.offline]
  bool get isOffline => ConnectivityStatus.offline == _status;

  /// Check if connected to [ConnectivityStatus.cellular]
  bool get isCellular => ConnectivityStatus.cellular == _status;

  /// Get current [ConnectivityState]
  ConnectivityState get state => ConnectivityState(_speed, _status, _quality);

  /// Get current [ConnectivityStatus]
  ConnectivityStatus get status => _status;
  ConnectivityStatus _status = ConnectivityStatus.cellular;

  /// Get current [ConnectivityQuality]
  ConnectivityQuality get quality => _quality;
  ConnectivityQuality _quality = ConnectivityQuality.good;

  /// Get current [ConnectivitySpeed]
  SpeedState get speed => _speed;
  SpeedState _speed = SpeedState.none;

  /// Get registered timeouts
  Map<Object, TimeoutResult> get timeouts => Map.unmodifiable(_timeouts);
  final _timeouts = <Object, TimeoutResult>{};

  /// Get registered [SpeedResult]s
  List<SpeedResult> get speedResults => List.unmodifiable(_speedResults);
  final _speedResults = <SpeedResult>[];

  /// Get stream of [ConnectivityStatus] changes
  Stream<ConnectivityStatus> get changes => _controller.stream;

  /// Get stream of [ConnectivityStatus] when changed to online
  Stream<ConnectivityStatus> get whenOnline => changes.where(
        (status) => ConnectivityStatus.offline != status,
      );

  /// Get stream of [ConnectivityStatus] when changed to offline
  Stream<ConnectivityStatus> get whenOffline => changes.where(
        (status) => ConnectivityStatus.offline == status,
      );

  /// Register timeout errors
  Future<ConnectivityState> onTimeout(Object error, {StackTrace stackTrace, bool analyse = false}) async {
    _timeouts.update(
      error.runtimeType,
      (result) => result.next(error, stackTrace),
      ifAbsent: () => TimeoutResult.first(error, stackTrace),
    );
    return analyse ? update() : state;
  }

  /// Register timeout errors
  Future<ConnectivityState> onSpeedResult(SpeedResult result, {bool analyse = false}) async {
    _speedResults.add(result);
    return analyse ? update() : state;
  }

  /// Update [ConnectivityState]
  Future<ConnectivityState> update() => Connectivity().checkConnectivity().then(_handleResult);

  final _delays = <Duration>[];

  /// The test to actually see if there is a connection
  Future<bool> test() async {
    final tic = DateTime.now();
    _hasConnection = await DataConnectionChecker().hasConnection;
    _delays.add(DateTime.now().difference(tic));
    return _hasConnection;
  }

  void _handleStatusChange(DataConnectionStatus status) {
    _hasConnection = DataConnectionStatus.connected == status;
    // Handle without checking internet connection
    _handleResult(_result, check: false);
  }

  Future<ConnectivityState> _handleResult(
    ConnectivityResult result, {
    bool check = true,
  }) async {
    if (check) {
      await test();
    }
    final previousStatus = _status;
    _result = _analyse(result);
    _status = _getStatusFromResult(result);
    if (previousStatus != _status) {
      _controller.add(_status);
    }
    return state;
  }

  ConnectivityResult _analyse(ConnectivityResult result) {
    if (_hasConnection) {
      _speed = _analyseSpeed();
      return _analyseQuality(result);
    }
    return ConnectivityResult.none;
  }

  SpeedState _analyseSpeed() {
    if (_speedResults.isNotEmpty) {
      while (_speedResults.length > 10) {
        _speedResults.remove(_speedResults.first);
      }
      final total = _speedResults.fold(0, (speed, result) => speed + result.speed);
      final speed = total ~/ _speedResults.length;
      if (speed < SpeedState.norm3g) {
        return SpeedState(
          speed,
          ConnectivitySpeed.slow,
        );
      } else if (speed < SpeedState.norm4g) {
        return SpeedState(
          speed,
          ConnectivitySpeed.fair,
        );
      }
      return SpeedState(
        speed,
        ConnectivitySpeed.high,
      );
    }
    return _speed;
  }

  ConnectivityResult _analyseQuality(ConnectivityResult result) {
    final timeouts = calcTimeouts();
    final failureRatio = calcFailureRatio();

    if (failureRatio > 0.5 || timeouts > 3) {
      _quality = ConnectivityQuality.bad;
      result = ConnectivityResult.none;
    } else if (failureRatio > 0.1 || timeouts > 1) {
      _quality = ConnectivityQuality.intermittent;
    } else {
      _quality = ConnectivityQuality.good;
    }
    return result;
  }

  int calcTimeouts() {
    final toc = DateTime.now();
    final timeouts = _timeouts.values
        .where((result) => toc.difference(result.timestamp) < const Duration(minutes: 1))
        .fold(0, (count, result) => count + result.count);
    return timeouts;
  }

  double calcFailureRatio() {
    final lastResults = DataConnectionChecker().lastTryResults;
    final lastSuccesses = lastResults.where((test) => test.isSuccess).length;
    final lastFailures = lastResults.length - lastSuccesses;
    final failureRatio = lastFailures / lastResults.length;
    return failureRatio;
  }

  ConnectivityStatus _getStatusFromResult(ConnectivityResult result) {
    if (_hasConnection) {
      switch (result) {
        case ConnectivityResult.mobile:
          return ConnectivityStatus.cellular;
        case ConnectivityResult.wifi:
          return ConnectivityStatus.wifi;
        case ConnectivityResult.none:
        default:
          break;
      }
    }
    return ConnectivityStatus.offline;
  }

  void dispose() {
    _disposed = true;
    _speedTimer?.cancel();
    _statusTimer?.cancel();
    _controller?.close();
    _subscriptions.forEach((sub) => sub.cancel());
  }
}

enum ConnectivitySpeed { high, fair, slow }

String translateConnectivitySpeed(ConnectivitySpeed type) {
  switch (type) {
    case ConnectivitySpeed.high:
      return 'Høy';
    case ConnectivitySpeed.fair:
      return 'OK';
    case ConnectivitySpeed.slow:
      return 'Treg';
    default:
      return enumName(type);
  }
}

enum ConnectivityQuality { good, intermittent, bad }

String translateConnectivityQuality(ConnectivityQuality type) {
  switch (type) {
    case ConnectivityQuality.good:
      return 'God';
    case ConnectivityQuality.intermittent:
      return 'Ustabil';
    case ConnectivityQuality.bad:
      return 'Dårlig';
    default:
      return enumName(type);
  }
}

enum ConnectivityStatus { wifi, cellular, offline }

String translateConnectivityStatus(ConnectivityStatus type) {
  switch (type) {
    case ConnectivityStatus.wifi:
      return 'WIFI';
    case ConnectivityStatus.cellular:
      return 'Mobil';
    case ConnectivityStatus.offline:
      return 'Offline';
    default:
      return enumName(type);
  }
}

class ConnectivityState {
  ConnectivityState(this.speed, this.status, this.quality);
  final SpeedState speed;
  final ConnectivityStatus status;
  final ConnectivityQuality quality;
}

class SpeedState {
  const SpeedState(this.usage, this.type);
  final int usage;
  final ConnectivitySpeed type;

  static const SpeedState none = SpeedState(0, ConnectivitySpeed.slow);

  static const int kib = 1024;
  static const int mib = kib * 1024;
  static const int gib = mib * 1024;

  static const int norm2g = 100 * kib;
  static const int norm3g = 8 * mib;
  static const int norm4g = 90 * mib;
  static const int norm5g = 150 * mib;

  String toString() {
    if (usage < kib) {
      return '$usage bit/s';
    } else if (usage < mib) {
      return '${usage ~/ kib} kbit/s';
    }
    return '${(usage ~/ mib)} mbit/s';
  }
}

class SpeedResult {
  SpeedResult(this.size, this.speed, this.method, this.duration);
  final int size;
  final int speed;
  final String method;
  final Duration duration;
}

enum SpeedUnit { kbs, mbs }

class TimeoutResult {
  TimeoutResult._(this.error, this.count, [this.stackTrace]);
  final int count;
  final Object error;
  final StackTrace stackTrace;
  final DateTime timestamp = DateTime.now();

  factory TimeoutResult.first(Object error, [StackTrace stackTrace]) => TimeoutResult._(error, 1);

  TimeoutResult next(Object error, StackTrace stackTrace,
      {Duration ttl = const Duration(
        minutes: 1,
      )}) {
    final prune = DateTime.now().difference(timestamp) > ttl;
    return TimeoutResult._(
      error,
      prune ? 0 : count + 1,
      stackTrace,
    );
  }
}
