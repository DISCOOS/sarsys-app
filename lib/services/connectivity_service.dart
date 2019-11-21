import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';

class ConnectivityService {
  static ConnectivityService _singleton;

  final StreamController<ConnectivityStatus> _controller = StreamController<ConnectivityStatus>.broadcast();

  bool _hasConnection = false;

  ConnectivityStatus _status = ConnectivityStatus.Offline;

  StreamSubscription _subscription;

  ConnectivityStatus get last => _status;
  Stream<ConnectivityStatus> get changes => _controller.stream;

  factory ConnectivityService() {
    if (_singleton == null) {
      _singleton = ConnectivityService._internal();
    }
    return _singleton;
  }

  ConnectivityService._internal() {
    _subscription = Connectivity().onConnectivityChanged.listen(_handle);
    if (Platform.isIOS) {
      Connectivity().checkConnectivity().then(_handle);
    }
  }

  void _handle(ConnectivityResult result) async {
    await test();
    final previousStatus = _status;
    _status = _getStatusFromResult(result);
    if (previousStatus != _status) _controller.add(_getStatusFromResult(result));
    // Retry?
    if (ConnectivityResult.none != result && _hasConnection == false) {
      Timer(Duration(seconds: 1), () {
        _handle(result);
      });
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
  Future test() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _hasConnection = true;
      } else {
        _hasConnection = false;
      }
    } on SocketException catch (_) {
      _hasConnection = false;
    }
    return _hasConnection;
  }

  void dispose() {
    _controller?.close();
    _subscription?.cancel();
  }
}

enum ConnectivityStatus { WiFi, Cellular, Offline }
