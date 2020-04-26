import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:data_connection_checker/data_connection_checker.dart';

class ConnectivityService {
  static ConnectivityService _singleton;

  final StreamController<ConnectivityStatus> _controller = StreamController<ConnectivityStatus>.broadcast();

  Timer _timer;
  StreamSubscription _subscription;

  ConnectivityResult _result = ConnectivityResult.none;

  ConnectivityStatus _status = ConnectivityStatus.cellular;
  ConnectivityStatus get status => _status;

  bool get isWifi => ConnectivityStatus.wifi == _status;
  bool get isOnline => ConnectivityStatus.offline != _status;
  bool get isOffline => ConnectivityStatus.offline == _status;
  bool get isCellular => ConnectivityStatus.cellular == _status;

  Stream<ConnectivityStatus> get changes => _controller.stream;
  Stream<ConnectivityStatus> get whenOnline => changes.where(
        (status) => ConnectivityStatus.offline != status,
      );
  Stream<ConnectivityStatus> get whenOffline => changes.where(
        (status) => ConnectivityStatus.offline == status,
      );

  bool _hasConnection = true;
  bool _disposed = false;

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
      _handle(result);
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        _handle(_result);
      });
    });
    _subscription = Connectivity().onConnectivityChanged.listen(_handle);
  }

  void _handle(ConnectivityResult result) async {
    await test();
    final previousStatus = _status;
    _result = result;
    _status = _getStatusFromResult(result);
    if (previousStatus != _status) {
      _controller.add(_status);
    }
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

  /// Update state
  Future<ConnectivityStatus> update() => Connectivity().checkConnectivity().then(_handle);

  /// The test to actually see if there is a connection
  Future<bool> test() async => _hasConnection = await DataConnectionChecker().hasConnection;

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller?.close();
    _subscription?.cancel();
  }
}

enum ConnectivityStatus { wifi, cellular, offline }
