import 'dart:async';

import 'package:connectivity/connectivity.dart';

class ConnectivityService {
  static ConnectivityService _singleton;

  final StreamController<ConnectivityStatus> _controller = StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription _subscription;

  Stream<ConnectivityStatus> get changes => _controller.stream;

  factory ConnectivityService() {
    if (_singleton == null) {
      _singleton = ConnectivityService._internal();
    }
    return _singleton;
  }

  ConnectivityService._internal() {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _controller.add(_getStatusFromResult(result));
    });
  }

  ConnectivityStatus _getStatusFromResult(ConnectivityResult result) {
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

  void dispose() {
    _controller?.close();
    _subscription?.cancel();
  }
}

enum ConnectivityStatus { WiFi, Cellular, Offline }
