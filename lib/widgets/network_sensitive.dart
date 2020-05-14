import 'package:SarSys/services/connectivity_service.dart';
import 'package:catcher/core/catcher.dart';
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
      initialData: service.status,
      create: (context) => ConnectivityService().changes,
      catchError: (error, stackTrace) => Catcher.reportCheckedError(
        error,
        stackTrace,
      ),
      child: child,
    );
  }
}
