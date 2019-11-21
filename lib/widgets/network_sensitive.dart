import 'package:SarSys/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NetworkSensitive extends StatelessWidget {
  final Widget child;
  final service = ConnectivityService();
  NetworkSensitive({
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamProvider<ConnectivityStatus>(
      initialData: service.last,
      builder: (context) => ConnectivityService().changes,
      child: child,
    );
  }
}
