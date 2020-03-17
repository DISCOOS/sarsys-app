import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:data_connection_checker/data_connection_checker.dart';

class ConnectivityService {
  static ConnectivityService _singleton;

  final StreamController<ConnectivityStatus> _controller = StreamController<ConnectivityStatus>.broadcast();

  bool _hasConnection = false;

  ConnectivityResult _result = ConnectivityResult.none;
  ConnectivityStatus _status = ConnectivityStatus.Offline;

  StreamSubscription _subscription;

  Timer _timer;

  ConnectivityStatus get last => _status;
  Stream<ConnectivityStatus> get changes => _controller.stream;

  factory ConnectivityService() {
    if (_singleton == null) {
      _singleton = ConnectivityService._internal();
    }
    return _singleton;
  }

  ConnectivityService._internal() {
    Connectivity().checkConnectivity().then((result) {
      _handle(result);
      _timer = Timer.periodic(Duration(seconds: 2), (_) {
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
          return ConnectivityStatus.Cellular;
        case ConnectivityResult.wifi:
          return ConnectivityStatus.WiFi;
        case ConnectivityResult.none:
          return ConnectivityStatus.Offline;
        default:
          return ConnectivityStatus.Offline;
      }
    }
    return ConnectivityStatus.Offline;
  }

  /// Update state
  Future<ConnectivityStatus> update() => Connectivity().checkConnectivity().then(_handle);

  /// The test to actually see if there is a connection
  Future<bool> test() async => _hasConnection = await DataConnectionChecker().hasConnection;

  void dispose() {
    _timer?.cancel();
    _controller?.close();
    _subscription?.cancel();
  }
}

enum ConnectivityStatus { WiFi, Cellular, Offline }
