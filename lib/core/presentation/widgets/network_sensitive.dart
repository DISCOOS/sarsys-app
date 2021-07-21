// @dart=2.11

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/error_handler.dart';
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
      catchError: (error, stackTrace) {
        SarSysApp.reportCheckedError(
          error,
          stackTrace,
        );
        return service.status;
      },
      child: child,
    );
  }
}
