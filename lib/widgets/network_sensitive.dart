import 'package:SarSys/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NetworkSensitive extends StatelessWidget {
  final Widget child;
  NetworkSensitive({
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamProvider<ConnectivityStatus>(
      builder: (context) => ConnectivityService().changes,
      child: child,
    );
  }
}
